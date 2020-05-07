defmodule Plausible.Session.WriteBuffer do
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

  def insert(session) do
    GenServer.cast(__MODULE__, {:insert, session})
    {:ok, session}
  end

  def handle_cast({:insert, session}, %{buffer: buffer} = state) do
    new_buffer = [ session | buffer ]

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
      sessions -> insert_sessions(sessions)
    end
  end

  defp insert_sessions(sessions) do
    Logger.debug("Flushing #{length(sessions)} sessions")
    insert = """
    INSERT INTO sessions (domain, user_id, hostname, start, is_bounce, entry_page, exit_page, referrer, referrer_source, country_code, screen_size, browser, operating_system)
    VALUES
    """ <> String.duplicate(" (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),", Enum.count(sessions))

    args = Enum.reduce(sessions, [], fn session, acc ->
      [session.domain, session.fingerprint, session.hostname, session.start, session.is_bounce && 1 || 0, session.entry_page, session.exit_page, session.referrer, session.referrer_source,session.country_code, session.screen_size, session.browser, session.operating_system] ++ acc
    end)

    Clickhousex.query(:clickhouse, insert, args, log: {Plausible.Stats, :log, []})
  end
end
