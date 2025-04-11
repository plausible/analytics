defmodule Plausible.Session.Transfer do
  @moduledoc """
  Cross-deployment transfer for `:sessions` cache.

  It works by establishing a client-server architecture where:
  - The "taker" one-time task retrieves `:sessions` data from other OS processes via Unix domain sockets
  - The "giver" server process responds to requests for `:sessions` data via Unix domain sockets
  - The "alive" process waits on shutdown for at least one taker, for 15 seconds
  """

  @behaviour Supervisor

  require Logger
  alias Plausible.Session.Transfer.{TinySock, Alive}

  def telemetry_event, do: [:plausible, :sessions, :transfer]

  @doc """
  Returns `true` if the transfer has been attempted (successfully or not).
  Returns `false` if the transfer is still in progress.
  """
  def attempted?(transfer \\ __MODULE__) do
    not taker_alive?(transfer)
  end

  defp taker_alive?(sup) do
    children = Supervisor.which_children(sup)
    taker = Enum.find_value(children, fn {id, pid, _, _} -> id == :taker && pid end)
    if is_pid(taker), do: Process.alive?(taker), else: false
  catch
    :exit, {:noproc, _} -> false
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
  def init(nil), do: :ignore

  def init(base_path) do
    File.mkdir_p!(base_path)

    taker =
      Supervisor.child_spec(
        {Task, fn -> take_all_ets_everywhere(base_path) end},
        id: :taker
      )

    given_counter = :counters.new(1, [])
    parent = self()

    giver =
      {TinySock,
       base_path: base_path,
       handler: fn message -> handle_taker(message, parent, given_counter) end}

    alive =
      Supervisor.child_spec(
        {Alive, _until = fn -> :counters.get(given_counter, 1) > 0 end},
        shutdown: :timer.seconds(15)
      )

    Supervisor.init([taker, giver, alive], strategy: :one_for_one)
  end

  defp session_version do
    [
      Plausible.ClickhouseSessionV2.module_info(:md5),
      Plausible.Cache.Adapter.module_info(:md5),
      Plausible.Session.CacheStore.module_info(:md5),
      Plausible.Session.Transfer.module_info(:md5)
    ]
  end

  defp handle_taker(message, parent, given_counter) do
    case message do
      {:list, session_version} ->
        if session_version == session_version() and attempted?(parent) do
          Plausible.Cache.Adapter.get_names(:sessions)
        else
          []
        end

      {:get, cache} ->
        Plausible.Cache.Adapter.cache2list(cache)

      :done ->
        :counters.add(given_counter, 1, 1)
    end
  end

  defp take_all_ets_everywhere(base_path) do
    started = System.monotonic_time()

    TinySock.list!(base_path)
    |> Enum.sort_by(&file_stat_ctime/1, :asc)
    |> Enum.each(&take_all_ets/1)

    :telemetry.execute(telemetry_event(), %{duration: System.monotonic_time() - started})
  end

  defp take_all_ets(sock) do
    with {:ok, names} <- TinySock.call(sock, {:list, session_version()}) do
      tasks = Enum.map(names, fn name -> Task.async(fn -> take_ets(sock, name) end) end)
      Task.await_many(tasks, :timer.seconds(10))
    end
  after
    TinySock.call(sock, :done)
  end

  defp take_ets(sock, cache) do
    with {:ok, records} <- TinySock.call(sock, {:get, cache}) do
      Enum.each(records, fn record ->
        {key, %Plausible.ClickhouseSessionV2{} = session} = record
        Plausible.Cache.Adapter.put(:sessions, key, session)
      end)
    end
  end

  defp file_stat_ctime(path) do
    case File.stat(path) do
      {:ok, stat} -> stat.ctime
      {:error, _} -> nil
    end
  end
end
