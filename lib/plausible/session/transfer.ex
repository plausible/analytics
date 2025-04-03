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

  def telemetry_event, do: [:plausible, :sessions, :transfer]

  def done?(transfer \\ __MODULE__) do
    not taker_alive?(transfer)
  end

  defp taker_alive?(sup) do
    children = Supervisor.which_children(sup)
    taker = Enum.find_value(children, fn {id, pid, _, _} -> id == :taker && pid end)
    if is_pid(taker), do: Process.alive?(taker), else: false
  catch
    :exit, :noproc -> false
  end

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      shutdown: :timer.seconds(20),
      restart: :temporary
    }
  end

  @doc false
  def start_link(opts) do
    base_path = Keyword.fetch!(opts, :base_path)
    name = Keyword.get(opts, :name, __MODULE__)
    maybe_start_link(name, base_path)
  end

  defp maybe_start_link(name, base_path) do
    cond do
      is_nil(base_path) ->
        :ignore

      :ok == TinySock.write_dir(base_path) ->
        do_start_link(name, base_path)

      true ->
        Logger.error("#{__MODULE__} failed to create directory #{inspect(base_path)}")
        :ignore
    end
  end

  defp do_start_link(name, base_path) do
    times_taken = :counters.new(1, [])
    times_given = :counters.new(1, [])

    taker =
      {Task,
       fn ->
         started = System.monotonic_time()
         take_all_ets_everywhere(base_path)
         duration = System.monotonic_time() - started
         :counters.add(times_taken, 1, 1)
         :telemetry.execute(telemetry_event(), %{duration: duration})
       end}

    giver =
      {TinySock,
       base_path: base_path,
       handler: fn
         {:list, session_version} ->
           if session_version == session_version() and :counters.get(times_taken, 1) > 0 do
             tabs()
           else
             []
           end

         {:send, tab} ->
           :ets.tab2list(tab)

         :took ->
           :counters.add(times_given, 1, 1)
       end}

    alive =
      {Alive,
       _until = fn ->
         :counters.get(times_given, 1) > 0
       end}

    children = [
      Supervisor.child_spec(taker, id: :taker),
      giver,
      Supervisor.child_spec(alive, shutdown: :timer.seconds(15))
    ]

    Supervisor.start_link(children, name: name, strategy: :one_for_one)
  end

  defp session_version do
    [
      Plausible.ClickhouseSessionV2.module_info(:md5),
      Plausible.Cache.Adapter.module_info(:md5),
      Plausible.Session.CacheStore.module_info(:md5),
      __MODULE__.module_info(:md5)
    ]
  end

  defp tabs() do
    Plausible.Cache.Adapter.get_names(:sessions)
    |> Enum.map(&ConCache.ets/1)
    |> Enum.filter(fn tab -> :ets.info(tab, :size) > 0 end)
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
