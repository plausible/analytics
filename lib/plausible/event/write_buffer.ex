defmodule Plausible.Event.WriteBuffer do
  use GenServer
  require Logger
  @flush_interval_ms 1000
  @max_buffer_size 10_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(buffer) do
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
      Logger.debug("Buffer full, flushing to disk")
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

  defp flush(buffer) do
    case buffer do
      [] -> nil
      events -> insert_events(events)
    end
  end

  defp insert_events(events) do
    Logger.debug("Flushing #{length(events)} events")
    insert = """
    INSERT INTO events (name, timestamp, domain, user_id, hostname, pathname, referrer, referrer_source, initial_referrer, initial_referrer_source, country_code, screen_size, browser, operating_system)
    VALUES
    """ <> String.duplicate(" (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),", length(events))

    args = Enum.reduce(events, [], fn event, acc ->
      [event.name, event.timestamp, event.domain, event.fingerprint, event.hostname, event.pathname, event.referrer, event.referrer_source, event.initial_referrer, event.initial_referrer_source, event.country_code, event.screen_size, event.browser, event.operating_system] ++ acc
    end)

    Clickhousex.query(:clickhouse, insert, args, log: {Plausible.Stats, :log, []})
  end
end
