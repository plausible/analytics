defmodule Plausible.Event.WriteBuffer do
  use GenServer
  require Logger

  alias Plausible.IngestRepo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], name: opts[:name] || __MODULE__)
  end

  def init(opts) do
    buffer = opts[:buffer] || []
    max_buffer_size = opts[:max_buffer_size] || default_max_buffer_size()
    flush_interval_ms = opts[:flush_interval_ms] || default_flush_interval_ms()

    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, flush_interval_ms)

    {:ok,
     %{
       buffer: buffer,
       timer: timer,
       buffer_size: length(buffer),
       max_buffer_size: max_buffer_size,
       flush_interval_ms: flush_interval_ms
     }}
  end

  def insert(server \\ __MODULE__, event) do
    GenServer.cast(server, {:insert, event})
    {:ok, event}
  end

  def flush(server \\ __MODULE__) do
    GenServer.call(server, :flush, :infinity)
    :ok
  end

  def handle_cast({:insert, event}, %{buffer: buffer} = state) do
    new_buffer = [event | buffer]
    new_buffer_size = state.buffer_size + 1

    if new_buffer_size >= state.max_buffer_size do
      Logger.info("Buffer full, flushing to disk")
      Process.cancel_timer(state.timer)
      do_flush(new_buffer)
      new_timer = Process.send_after(self(), :tick, state.flush_interval_ms)
      {:noreply, %{state | buffer: [], timer: new_timer, buffer_size: 0}}
    else
      {:noreply, %{state | buffer: new_buffer, buffer_size: new_buffer_size}}
    end
  end

  def handle_info(:tick, %{buffer: buffer} = state) do
    do_flush(buffer)
    timer = Process.send_after(self(), :tick, state.flush_interval_ms)
    {:noreply, %{state | buffer: [], buffer_size: 0, timer: timer}}
  end

  def handle_call(:flush, _from, %{buffer: buffer} = state) do
    Process.cancel_timer(state.timer)
    do_flush(buffer)
    new_timer = Process.send_after(self(), :tick, state.flush_interval_ms)
    {:reply, :ok, %{state | buffer: [], buffer_size: 0, timer: new_timer}}
  end

  def terminate(_reason, %{buffer: buffer}) do
    Logger.info("Flushing event buffer before shutdown...")
    do_flush(buffer)
  end

  defp do_flush(buffer) do
    case buffer do
      [] ->
        nil

      events ->
        Logger.info("Flushing #{length(events)} events")
        events = Enum.map(events, &(Map.from_struct(&1) |> Map.delete(:__meta__)))
        IngestRepo.insert_all(Plausible.ClickhouseEventV2, events)
    end
  end

  defp default_flush_interval_ms do
    Keyword.fetch!(Application.get_env(:plausible, IngestRepo), :flush_interval_ms)
  end

  defp default_max_buffer_size do
    Keyword.fetch!(Application.get_env(:plausible, IngestRepo), :max_buffer_size)
  end
end
