defmodule Plausible.Event.WriteBuffer do
  use GenServer
  require Logger
  alias Plausible.Clickhouse
  @flush_interval_ms 5_000
  @max_buffer_size 10_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(buffer) do
    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, @flush_interval_ms)
    {:ok, %{buffer: buffer, timer: timer}}
  end

  def insert(event) do
    GenServer.cast(__MODULE__, {:insert, event})
    {:ok, event}
  end

  def handle_cast({:insert, event}, %{buffer: buffer} = state) do
    new_buffer = [ event | buffer ]

    if length(new_buffer) >= @max_buffer_size do
      Logger.info("Buffer full, flushing to disk")
      Process.cancel_timer(state[:timer])
      flush(new_buffer)
      new_timer = Process.send_after(self(), :tick, @flush_interval_ms)
      {:noreply, %{buffer: [], timer: new_timer}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  def handle_info(:tick, %{buffer: buffer}) do
    flush(buffer)
    timer = Process.send_after(self(), :tick, @flush_interval_ms)
    {:noreply, %{buffer: [], timer: timer}}
  end

  def terminate(_reason, %{buffer: buffer}) do
    Logger.info("Flushing event buffer before shutdown...")
    flush(buffer)
  end

  defp flush(buffer) do
    case buffer do
      [] -> nil
      events ->
        Logger.info("Flushing #{length(events)} events")
        Clickhouse.insert_events(events)
    end
  end
end
