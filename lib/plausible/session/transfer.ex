defmodule Plausible.Session.Transfer do
  @moduledoc """
  Cross-deployment transfer for `:sessions` cache.

  It works by establishing a client-server architecture where:
  - The "taker" one-time task retrieves ETS data from other processes via Unix domain sockets
  - The "giver" server process responds to requests for ETS data via Unix domain sockets
  - The "alive" process waits on shutdown for at least one taker, for 15 seconds
  """

  require Logger

  alias Plausible.ClickhouseSessionV2
  alias Plausible.Session.Transfer.{TinySock, Alive}

  def took?, do: Application.get_env(:plausible, :took_sessions, false)
  defp took, do: Application.put_env(:plausible, :took_sessions, true)

  def gave?, do: Application.get_env(:plausible, :gave_sessions, false)
  defp gave, do: Application.put_env(:plausible, :gave_sessions, true)

  def telemetry_event, do: [:plausible, :sessions, :transfer]

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc false
  def start_link(opts) do
    result = maybe_start_link(Keyword.fetch!(opts, :base_path))

    if result == :ignore do
      took()
    end

    result
  end

  defp maybe_start_link(base_path) do
    cond do
      is_nil(base_path) ->
        :ignore

      :ok == TinySock.write_dir(base_path) ->
        do_start_link(base_path)

      true ->
        Logger.error("#{__MODULE__} failed to create directory #{inspect(base_path)}")
        :ignore
    end
  end

  defp do_start_link(base_path) do
    taker = {Task, fn -> try_take_all_ets_everywhere(base_path) end}
    giver = {TinySock, base_path: base_path, handler: &giver_handler/1}
    alive = {Alive, until: &gave?/0}

    children = [
      Supervisor.child_spec(taker, restart: :temporary),
      Supervisor.child_spec(giver, restart: :transient),
      Supervisor.child_spec(alive, shutdown: :timer.seconds(15))
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp session_version do
    IO.iodata_to_binary([
      ClickhouseSessionV2.module_info(:md5),
      # ClickhouseSessionV2.BoolUInt8.module_info(:md5),
      # Ch.module_info(:md5),
      # Plausible.Cache.Adapter.module_info(:md5),
      # __MODULE__.module_info(:md5),
      Plausible.Session.CacheStore.module_info(:md5)
    ])
  end

  defp giver_handler(message) do
    case message do
      {:list, session_version} -> tabs(session_version)
      {:send, tab} -> dumpscan(tab)
      :took -> gave()
    end
  end

  defp tabs(session_version) do
    if session_version == session_version() and took?() do
      Plausible.Cache.Adapter.get_names(:sessions)
      |> Enum.map(&ConCache.ets/1)
      |> Enum.filter(fn tab -> :ets.info(tab, :size) > 0 end)
    else
      []
    end
  end

  defp maybe_ets_whereis(tab) when is_atom(tab), do: :ets.whereis(tab)
  defp maybe_ets_whereis(tab) when is_reference(tab), do: tab

  defp dumpscan(tab) do
    tab = maybe_ets_whereis(tab)
    :ets.safe_fixtable(tab, true)

    try do
      dumpscan_continue(:ets.first_lookup(tab), _acc = [], tab)
    after
      :ets.safe_fixtable(tab, false)
    end
  end

  defp dumpscan_continue({k, [record]}, acc, tab) do
    {key, %ClickhouseSessionV2{} = session} = record
    params = Map.filter(session, &__MODULE__.session_params_filter/1)
    dumpscan_continue(:ets.next_lookup(tab, k), [{key, params} | acc], tab)
  end

  defp dumpscan_continue(:"$end_of_table", acc, _tab) do
    acc
  end

  @doc false
  def session_params_filter({:__struct__, _}), do: false
  def session_params_filter({:__meta__, _}), do: false
  def session_params_filter({_, nil}), do: false
  def session_params_filter({_, _}), do: true

  defp try_take_all_ets_everywhere(base_path) do
    counter = :counters.new(1, [:write_concurrency])
    started = System.monotonic_time()

    try do
      take_all_ets_everywhere(base_path, counter)
    after
      count = :counters.get(counter, 1)
      duration = System.monotonic_time() - started
      :telemetry.execute(telemetry_event(), %{count: count, duration: duration})
      took()
    end
  end

  defp take_all_ets_everywhere(base_path, counter) do
    with {:ok, socks} <- TinySock.list(base_path) do
      socks
      |> Enum.sort_by(&file_stat_ctime/1, :asc)
      |> Enum.each(fn sock -> take_all_ets(sock, counter) end)
    end
  end

  defp file_stat_ctime(path) do
    case File.stat(path) do
      {:ok, stat} -> stat.ctime
      {:error, _} -> 0
    end
  end

  defp take_all_ets(sock, counter) do
    with {:ok, tabs} <- TinySock.call(sock, {:list, session_version()}) do
      tasks = Enum.map(tabs, fn tab -> Task.async(fn -> take_one_ets(sock, counter, tab) end) end)
      Task.await_many(tasks)
    end
  after
    TinySock.call(sock, :took)
  end

  defp take_one_ets(sock, counter, tab) do
    with {:ok, records} <- TinySock.call(sock, {:send, tab}) do
      savescan(records, counter)
    end
  end

  @session_fields ClickhouseSessionV2.__schema__(:fields)

  defp savescan([{key, session} | rest], counter) do
    changeset = Ecto.Changeset.cast(%ClickhouseSessionV2{}, session, @session_fields)

    if changeset.valid? do
      new_session = Ecto.Changeset.apply_changes(changeset)
      old_session = Plausible.Cache.Adapter.get(:sessions, key)

      if is_nil(old_session) or new_session.events >= old_session.events do
        Plausible.Cache.Adapter.put(:sessions, key, new_session)
        :counters.add(counter, 1, 1)
      end
    end

    savescan(rest, counter)
  end

  defp savescan([], _counter), do: :ok
end
