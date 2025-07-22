defmodule Plausible.Session.Transfer do
  @moduledoc """
  Cross-deployment transfer for `:sessions` cache.

  It works by establishing a client-server architecture where:
  - The "replica" one-time task retrieves `:sessions` data from other OS processes via Unix domain sockets
  - The "primary" server process responds to requests for `:sessions` data via Unix domain sockets
  - The "alive" process waits on shutdown for at least one replica, for 15 seconds
  """

  @behaviour Supervisor

  require Logger
  alias Plausible.Session.Transfer.{TinySock, Alive}
  alias Plausible.{Cache, ClickhouseSessionV2, Session}

  @cmd_list_cache_names :list
  @cmd_dump_cache :get
  @cmd_takeover_done :done

  def telemetry_event, do: [:plausible, :sessions, :takeover]

  @doc """
  Starts the `:sessions` transfer supervisor.

  Options:
  - `:name` - the name of the supervisor (default: `Plausible.Session.Transfer`)
  - `:base_path` - the base path for the Unix domain sockets (required)
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    base_path = Keyword.fetch!(opts, :base_path)
    Supervisor.start_link(__MODULE__, base_path, name: name)
  end

  @impl true
  def init(nil) do
    Logger.notice(
      "Session transfer: ignoring, no socket base path configured (make sure ENABLE_SESSION_TRANSFER/PERSISTENT_CACHE_DIR are set)"
    )

    :ignore
  end

  def init(base_path) do
    File.mkdir_p!(base_path)

    replica =
      Supervisor.child_spec(
        {Task, fn -> init_takeover(base_path) end},
        id: :transfer_replica
      )

    given_counter = :counters.new(1, [])
    parent = self()

    primary =
      {TinySock,
       base_path: base_path,
       handler: fn message -> handle_replica(message, parent, given_counter) end}

    alive =
      Supervisor.child_spec(
        {Alive,
         _until = fn ->
           result = :counters.get(given_counter, 1) > 0

           Logger.notice(
             "Session transfer delayed shut down. Checking if session takeover happened?: #{result}"
           )

           result
         end},
        shutdown: :timer.seconds(15)
      )

    Logger.info("Session transfer init: #{base_path}")
    Supervisor.init([replica, primary, alive], strategy: :one_for_one)
  end

  @doc """
  Returns `true` if the transfer has been attempted (successfully or not).
  Returns `false` if the transfer is still in progress.
  """
  def attempted?(transfer_sup \\ __MODULE__) do
    result = not replica_alive?(transfer_sup)
    Logger.notice("Session transfer attempted?: #{result}")
    result
  end

  @doc """
  Returns the child specification for the `:sessions` transfer supervisor.
  See `start_link/1` for options.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :temporary
    }
  end

  defp handle_replica(request, parent, given_counter) do
    Logger.notice(
      "Session transfer message received at #{node()}: #{inspect(request, limit: 10)}"
    )

    case request do
      {@cmd_list_cache_names, session_version} ->
        if session_version == session_version() and attempted?(parent) do
          Cache.Adapter.get_names(:sessions)
        else
          []
        end

      {@cmd_dump_cache, cache} ->
        Cache.Adapter.cache2list(cache)

      @cmd_takeover_done ->
        :counters.add(given_counter, 1, 1)
    end
  end

  defp init_takeover(base_path) do
    started = System.monotonic_time()

    base_path
    |> TinySock.list!()
    |> Enum.sort_by(&file_stat_ctime/1, :asc)
    |> Enum.each(&request_takeover/1)

    :telemetry.execute(telemetry_event(), %{duration: System.monotonic_time() - started})
  end

  defp request_takeover(sock) do
    Logger.notice("Session transfer: requesting takeover at #{node()}")

    with {:ok, names} <- TinySock.call(sock, {@cmd_list_cache_names, session_version()}) do
      tasks = Enum.map(names, fn name -> Task.async(fn -> takeover_cache(sock, name) end) end)
      Task.await_many(tasks, :timer.seconds(10))
    end
  after
    Logger.notice("Session transfer: marking takeover as done at #{node()}")
    TinySock.call(sock, @cmd_takeover_done)
  end

  defp takeover_cache(sock, cache) do
    Logger.notice("Session transfer: requesting cache #{cache} dump at #{node()}")

    with {:ok, records} <- TinySock.call(sock, {@cmd_dump_cache, cache}) do
      Enum.each(records, fn record ->
        {key, %ClickhouseSessionV2{} = session} = record
        Cache.Adapter.put(:sessions, key, session)
      end)

      Logger.notice("Session transfer: restored cache #{cache} at #{node()}")
    end
  end

  defp file_stat_ctime(path) do
    case File.stat(path) do
      {:ok, stat} -> stat.ctime
      {:error, _} -> nil
    end
  end

  defp session_version do
    [
      ClickhouseSessionV2.module_info(:md5),
      Cache.Adapter.module_info(:md5),
      Session.CacheStore.module_info(:md5),
      Session.Transfer.module_info(:md5)
    ]
  end

  defp replica_alive?(transfer_sup) do
    children = Supervisor.which_children(transfer_sup)

    replica =
      Enum.find_value(children, fn {id, pid, _, _} -> id == :transfer_replica && pid end)

    is_pid(replica) and Process.alive?(replica)
  catch
    :exit, {:noproc, _} -> false
  end
end
