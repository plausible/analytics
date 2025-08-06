defmodule Plausible.Session.WriteBuffer do
  @moduledoc false

  %{
    header: header,
    insert_sql: insert_sql,
    insert_opts: insert_opts,
    fields: fields,
    encoding_types: encoding_types
  } =
    Plausible.Ingestion.WriteBuffer.compile_time_prepare(Plausible.ClickhouseSessionV2)

  def child_spec(opts) do
    opts =
      Keyword.merge(opts,
        name: __MODULE__,
        header: unquote(header),
        insert_sql: unquote(insert_sql),
        insert_opts: unquote(insert_opts),
        on_init: &Plausible.Session.WriteBuffer.on_init/1,
        on_flush: &Plausible.Session.WriteBuffer.on_flush/2
      )

    Plausible.Ingestion.WriteBuffer.child_spec(opts)
  end

  def insert(sessions) do
    row_binary =
      sessions
      |> Enum.map(fn %{is_bounce: is_bounce} = session ->
        {:ok, is_bounce} = Plausible.ClickhouseSessionV2.BoolUInt8.dump(is_bounce)
        session = %{session | is_bounce: is_bounce}
        Enum.map(unquote(fields), fn field -> Map.fetch!(session, field) end)
      end)
      |> Ch.RowBinary._encode_rows(unquote(encoding_types))
      |> IO.iodata_to_binary()

    :ok = Plausible.Ingestion.WriteBuffer.insert(__MODULE__, row_binary)
    {:ok, sessions}
  end

  def flush do
    Plausible.Ingestion.WriteBuffer.flush(__MODULE__)
  end

  @doc false
  def on_init(opts) do
    name = Keyword.fetch!(opts, :name)

    ^name = :ets.new(name, [:named_table, :set, :public])

    %{
      lock_timeout_ms: opts[:lock_timeouts_ms] || default_lock_timeout_ms(),
      lock_interval_ms: opts[:lock_interval_ms] || default_lock_interval_ms()
    }
  end

  @doc false
  def on_flush(_, state) do
    case :ets.lookup(state.name, :state) do
      [state: %{locker: pid}] when is_pid(pid) ->
        send(pid, {:locked, state.name})
        now = System.monotonic_time()
        lock_loop(state.name, now, state.lock_timeout_ms, state.lock_interval_ms)

      _ ->
        :ignore
    end

    state
  end

  def lock(timeout \\ nil) do
    locker = self()
    timeout = timeout || default_lock_acquire_timeout_ms()
    name = __MODULE__

    true = :ets.insert(name, {:state, %{locker: locker}})
    Plausible.Ingestion.WriteBuffer.flush_async(name)

    receive do
      {:locked, ^name} -> :ok
    after
      timeout -> {:error, :timeout}
    end
  end

  def unlock() do
    name = __MODULE__
    true = :ets.insert(name, {:state, %{locker: nil}})

    :ok
  end

  defp lock_loop(name, start, lock_timeout, lock_interval) do
    now = System.monotonic_time()

    if now - start <= lock_timeout do
      Process.sleep(lock_interval)

      case :ets.lookup(name, :state) do
        [state: %{locker: pid}] when is_pid(pid) ->
          lock_loop(name, start, lock_timeout, lock_interval)

        _ ->
          :pass
      end
    else
      # Wipe the cache before unlocking to prevent stale session in case
      # transfer actually occurs, either partially or completely
      Plausible.Cache.Adapter.wipe(:sessions)
      unlock()
    end
  end

  defp default_lock_acquire_timeout_ms do
    Keyword.fetch!(Application.get_env(:plausible, __MODULE__), :lock_acquire_timeout_ms)
  end

  defp default_lock_timeout_ms do
    Keyword.fetch!(Application.get_env(:plausible, __MODULE__), :lock_timeout_ms)
  end

  defp default_lock_interval_ms do
    Keyword.fetch!(Application.get_env(:plausible, __MODULE__), :lock_interval_ms)
  end
end
