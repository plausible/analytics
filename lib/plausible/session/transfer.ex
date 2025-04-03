defmodule Plausible.Session.Transfer do
  @moduledoc """
  Cross-deployment transfer for `:sessions` cache.

  It works by establishing a client-server architecture where:
  - The "taker" one-time task retrieves ETS data from other processes via Unix domain sockets
  - The "giver" server process responds to requests for ETS data via Unix domain sockets
  - The "alive" process waits on shutdown for at least one taker, for 15 seconds
  """

  require Logger
  alias Plausible.Session.Transfer.{TinySock, Alive}

  def took?, do: Application.get_env(:plausible, :took_sessions, false)
  defp took, do: Application.put_env(:plausible, :took_sessions, true)

  # TODO await took?

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
    [
      Plausible.ClickhouseSessionV2.module_info(:md5),
      Plausible.Cache.Adapter.module_info(:md5),
      Plausible.Session.CacheStore.module_info(:md5),
      __MODULE__.module_info(:md5)
    ]
  end

  @doc false
  def giver_handler(message) do
    case message do
      {:list, session_version} -> tabs(session_version)
      {:send, tab} -> :ets.tab2list(tab)
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

  @doc false
  def try_take_all_ets_everywhere(base_path) do
    started = System.monotonic_time()

    try do
      take_all_ets_everywhere(base_path)
    after
      duration = System.monotonic_time() - started
      :telemetry.execute(telemetry_event(), %{duration: duration})
      took()
    end
  end

  defp take_all_ets_everywhere(base_path) do
    with {:ok, socks} <- TinySock.list(base_path) do
      socks
      |> Enum.sort_by(&file_stat_ctime/1, :asc)
      |> Enum.each(&take_all_ets/1)
    end
  end

  defp file_stat_ctime(path) do
    case File.stat(path) do
      {:ok, stat} -> stat.ctime
      {:error, _} -> nil
    end
  end

  defp take_all_ets(sock) do
    with {:ok, tabs} <- TinySock.call(sock, {:list, session_version()}) do
      tasks = Enum.map(tabs, fn tab -> Task.async(fn -> take_ets(sock, tab) end) end)
      Task.await_many(tasks, :timer.seconds(10))
    end
  after
    TinySock.call(sock, :took)
  end

  defp take_ets(sock, tab) do
    with {:ok, records} <- TinySock.call(sock, {:send, tab}) do
      Plausible.Cache.Adapter.put_many(:sessions, records)
    end
  end
end
