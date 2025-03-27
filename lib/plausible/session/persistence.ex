defmodule Plausible.Session.Persistence do
  @moduledoc """
  Inter-process persistence and sharing for `:sessions` cache during deployments.

  It works by establishing a client-server architecture where:
  - The "taker" one-time task retrieves ETS data from other processes via Unix domain sockets
  - The "giver" server process responds to requests for ETS data via Unix domain sockets
  """

  alias Plausible.ClickhouseSessionV2
  alias Plausible.Session.Persistence.TinySock

  @took_sessions_key :took_sessions
  def took?, do: Application.get_env(:plausible, @took_sessions_key, false)
  defp took, do: Application.put_env(:plausible, @took_sessions_key, true)

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
    base_path = Keyword.fetch!(opts, :base_path)

    taker = {Task, fn -> take_ets(base_path) end}
    giver = {TinySock, base_path: base_path, handler: &giver_handler/1}

    children = [
      # Supervisor.child_spec(DumpRestore, restart: :transient),
      Supervisor.child_spec(taker, restart: :temporary),
      Supervisor.child_spec(giver, restart: :transient)
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp session_version do
    ClickhouseSessionV2.module_info()[:md5]
  end

  @give_tag "GIVE-ETS"

  @doc false
  def take_ets(base_path) do
    socks = TinySock.list(base_path)
    session_version = session_version()

    Enum.each(socks, fn sock ->
      dump_path = Path.join(base_path, "dump" <> Base.url_encode64(:crypto.strong_rand_bytes(6)))
      File.mkdir_p!(dump_path)

      try do
        dumps = TinySock.call(sock, {@give_tag, session_version, dump_path})

        tasks =
          Enum.map(dumps, fn path ->
            Task.async(fn -> scansave(File.read!(path)) end)
          end)

        Task.await_many(tasks)
      after
        File.rm_rf!(dump_path)
      end
    end)
  after
    took()
  end

  @doc false
  def giver_handler({@give_tag, session_version, dump_path}) do
    if session_version == session_version() do
      give_ets(dump_path)
    else
      []
    end
  end

  @doc false
  def give_ets(dump_path) do
    cache_names = Plausible.Cache.Adapter.get_names(:sessions)

    dumps =
      Enum.map(cache_names, fn cache_name ->
        tab = ConCache.ets(cache_name)
        path = Path.join(dump_path, to_string(cache_name))
        {path, Task.async(fn -> dumpscan(tab, path) end)}
      end)

    Enum.reduce(dumps, [], fn {path, task}, paths ->
      :ok = Task.await(task)
      [path | paths]
    end)
  end

  defp dumpscan(tab, file) do
    tab = :ets.whereis(tab)
    :ets.safe_fixtable(tab, true)

    File.rm(file)
    fd = File.open!(file, [:raw, :binary, :append, :exclusive])

    try do
      dumpscan(:ets.first_lookup(tab), [], 0, tab, fd)
    after
      :ok = File.close(fd)
      :ets.safe_fixtable(tab, false)
    end
  end

  defp dumpscan({k, [record]}, cache, cache_len, tab, fd) do
    {_user_id, %ClickhouseSessionV2{}} = record

    bin = :erlang.term_to_binary(record)
    bin_len = byte_size(bin)

    true = bin_len < 4_294_967_296

    new_cache = append_cache(cache, <<bin_len::32, bin::bytes>>)
    new_cache_len = cache_len + bin_len + 4

    if new_cache_len > 500_000 do
      :ok = :file.write(fd, new_cache)
      dumpscan(:ets.next_lookup(tab, k), [], 0, tab, fd)
    else
      dumpscan(:ets.next_lookup(tab, k), new_cache, new_cache_len, tab, fd)
    end
  end

  defp dumpscan(:"$end_of_table", cache, cache_len, _tab, fd) do
    if cache_len > 0 do
      :ok = :file.write(fd, cache)
    end

    :ok
  end

  @dialyzer :no_improper_lists
  @compile {:inline, append_cache: 2}
  defp append_cache([], bin), do: bin
  defp append_cache(cache, bin), do: [cache | bin]

  defp scansave(<<bin_len::32, bin::size(bin_len)-bytes, rest::bytes>>) do
    {user_id, %ClickhouseSessionV2{} = session} = :erlang.binary_to_term(bin, [:safe])
    Plausible.Cache.Adapter.put(:sessions, user_id, session)
    scansave(rest)
  end

  defp scansave(<<>>), do: :ok
end
