defmodule Plausible.Ingestion.WriteBuffer do
  use GenServer
  require Logger

  alias Plausible.IngestRepo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  def insert(server, schema, value) do
    GenServer.cast(server, {:insert, encode_rows(schema, value)})
    {:ok, value}
  end

  def flush(server) do
    GenServer.call(server, :flush, :infinity)
    :ok
  end

  @impl true
  def init(opts) do
    buffer = opts[:buffer] || []
    max_buffer_size = opts[:max_buffer_size] || default_max_buffer_size()
    flush_interval_ms = opts[:flush_interval_ms] || default_flush_interval_ms()
    schema = Keyword.fetch!(opts, :schema)

    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, flush_interval_ms)

    {:ok,
     %{
       buffer: buffer,
       timer: timer,
       insert_sql: insert_sql(schema),
       header: row_binary_header(schema),
       buffer_size: length(buffer),
       max_buffer_size: max_buffer_size,
       flush_interval_ms: flush_interval_ms
     }}
  end

  @impl true
  def handle_cast({:insert, row_binary}, %{buffer: buffer} = state) do
    state = %{state | buffer: [buffer | row_binary], buffer_size: state.buffer_size + 1}

    if state.buffer_size >= state.max_buffer_size do
      Logger.info("Buffer full, flushing to ClickHouse")
      Process.cancel_timer(state.timer)
      do_flush(state)
      new_timer = Process.send_after(self(), :tick, state.flush_interval_ms)
      {:noreply, %{state | buffer: [], timer: new_timer, buffer_size: 0}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    do_flush(state)
    timer = Process.send_after(self(), :tick, state.flush_interval_ms)
    {:noreply, %{state | buffer: [], buffer_size: 0, timer: timer}}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    Process.cancel_timer(state.timer)
    do_flush(state)
    new_timer = Process.send_after(self(), :tick, state.flush_interval_ms)
    {:reply, :ok, %{state | buffer: [], buffer_size: 0, timer: new_timer}}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("Flushing #{state.schema} buffer before shutdown...")
    do_flush(state)
  end

  defp do_flush(%{buffer: buffer} = state) do
    case buffer do
      [] ->
        nil

      _not_empty ->
        Logger.info("Flushing #{state.buffer_size} #{state.schema}")

        IngestRepo.query!(state.insert_sql, [state.header | buffer],
          command: :insert,
          encode: false
        )
    end
  end

  defp default_flush_interval_ms do
    Keyword.fetch!(Application.get_env(:plausible, IngestRepo), :flush_interval_ms)
  end

  defp default_max_buffer_size do
    Keyword.fetch!(Application.get_env(:plausible, IngestRepo), :max_buffer_size)
  end

  defp insert_sql(schema) do
    "INSERT INTO #{schema.__schema__(:source)} FORMAT RowBinaryWithNamesAndTypes"
  end

  defp row_binary_header(schema) do
    fields = schema.__schema__(:fields)
    types = Enum.map(fields, fn field -> extract_type(schema, field) end)
    names = Enum.map(fields, &String.Chars.Atom.to_string/1)
    Ch.RowBinary.encode_names_and_types(names, types)
  end

  defp extract_type(schema, field) do
    type = schema.__schema__(:type, field) || raise "missing type for #{field}"
    type |> Ecto.Type.type() |> Ecto.Adapters.ClickHouse.Schema.remap_type(schema, field)
  end

  def encode_rows(schema, %{} = struct) do
    fields = schema.__schema__(:fields)
    types = Enum.map(fields, fn field -> extract_type(schema, field) end)
    values = Enum.map(fields, fn field -> Map.fetch!(struct, field) end)
    Ch.RowBinary.encode_row(values, types)
  end

  def encode_rows(schema, [_ | _] = structs) do
    fields = schema.__schema__(:fields)
    types = Enum.map(fields, fn field -> extract_type(schema, field) end)

    values =
      Enum.map(structs, fn struct ->
        Enum.map(fields, fn field -> Map.fetch!(struct, field) end)
      end)

    Ch.RowBinary.encode_rows(values, types)
  end
end
