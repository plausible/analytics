defmodule Plausible.Ingestion.WriteBuffer do
  @moduledoc false
  use GenServer
  require Logger

  alias Plausible.IngestRepo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  def insert(server, row_binary) do
    GenServer.cast(server, {:insert, row_binary})
  end

  def flush(server) do
    GenServer.call(server, :flush, :infinity)
  end

  def flush_async(server) do
    GenServer.cast(server, :flush)
  end

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    buffer = opts[:buffer] || []
    max_buffer_size = opts[:max_buffer_size] || default_max_buffer_size()
    flush_interval_ms = opts[:flush_interval_ms] || default_flush_interval_ms()
    on_init = Keyword.get(opts, :on_init, fn _opts -> %{} end)

    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, flush_interval_ms)

    extra_state = on_init.(opts)

    {:ok,
     Map.merge(
       %{
         buffer: buffer,
         timer: timer,
         name: name,
         insert_sql: Keyword.fetch!(opts, :insert_sql),
         insert_opts: Keyword.fetch!(opts, :insert_opts),
         on_flush: Keyword.get(opts, :on_flush, fn _result, state -> state end),
         header: Keyword.fetch!(opts, :header),
         buffer_size: IO.iodata_length(buffer),
         max_buffer_size: max_buffer_size,
         flush_interval_ms: flush_interval_ms
       },
       extra_state
     )}
  end

  @impl true
  def handle_cast({:insert, row_binary}, state) do
    state = %{
      state
      | buffer: [state.buffer | row_binary],
        buffer_size: state.buffer_size + IO.iodata_length(row_binary)
    }

    if state.buffer_size >= state.max_buffer_size do
      Logger.notice("#{state.name} buffer full, flushing to ClickHouse")
      Process.cancel_timer(state.timer)
      do_flush(state)
      new_timer = Process.send_after(self(), :tick, state.flush_interval_ms)
      {:noreply, %{state | buffer: [], timer: new_timer, buffer_size: 0}}
    else
      {:noreply, state}
    end
  end

  def handle_cast(:flush, state) do
    %{timer: timer, flush_interval_ms: flush_interval_ms} = state
    Process.cancel_timer(timer)
    do_flush(state)
    new_timer = Process.send_after(self(), :tick, flush_interval_ms)
    {:noreply, %{state | buffer: [], buffer_size: 0, timer: new_timer}}
  end

  @impl true
  def handle_info(:tick, state) do
    do_flush(state)
    timer = Process.send_after(self(), :tick, state.flush_interval_ms)
    {:noreply, %{state | buffer: [], buffer_size: 0, timer: timer}}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    %{timer: timer, flush_interval_ms: flush_interval_ms} = state
    Process.cancel_timer(timer)
    do_flush(state)
    new_timer = Process.send_after(self(), :tick, flush_interval_ms)
    {:reply, :ok, %{state | buffer: [], buffer_size: 0, timer: new_timer}}
  end

  @impl true
  def terminate(_reason, %{name: name} = state) do
    Logger.notice("Flushing #{name} buffer before shutdown...")
    do_flush(state)
  end

  defp do_flush(state) do
    %{
      buffer: buffer,
      buffer_size: buffer_size,
      insert_opts: insert_opts,
      insert_sql: insert_sql,
      header: header,
      name: name,
      on_flush: on_flush
    } = state

    case buffer do
      [] ->
        on_flush.(:empty, state)

      _not_empty ->
        Logger.notice("Flushing #{buffer_size} byte(s) RowBinary from #{name}")
        IngestRepo.query!(insert_sql, [header | buffer], insert_opts)
        on_flush.(:success, state)
    end
  end

  defp default_flush_interval_ms do
    Keyword.fetch!(Application.get_env(:plausible, IngestRepo), :flush_interval_ms)
  end

  defp default_max_buffer_size do
    Keyword.fetch!(Application.get_env(:plausible, IngestRepo), :max_buffer_size)
  end

  @doc false
  def compile_time_prepare(schema) do
    fields =
      schema.__schema__(:fields)
      |> Enum.reject(&(&1 in fields_to_ignore()))

    types =
      Enum.map(fields, fn field ->
        type = schema.__schema__(:type, field) || raise "missing type for #{field}"

        type
        |> Ecto.Type.type()
        |> Ecto.Adapters.ClickHouse.Schema.remap_type(schema, field)
      end)

    encoding_types = Ch.RowBinary.encoding_types(types)

    header =
      fields
      |> Enum.map(&to_string/1)
      |> Ch.RowBinary.encode_names_and_types(types)
      |> IO.iodata_to_binary()

    insert_sql =
      "INSERT INTO #{schema.__schema__(:source)} (#{Enum.join(fields, ", ")}) FORMAT RowBinaryWithNamesAndTypes"

    %{
      fields: fields,
      types: types,
      encoding_types: encoding_types,
      header: header,
      insert_sql: insert_sql,
      insert_opts: [
        command: :insert,
        encode: false,
        source: schema.__schema__(:source),
        cast_params: []
      ]
    }
  end

  defp fields_to_ignore(), do: [:acquisition_channel, :interactive?]
end
