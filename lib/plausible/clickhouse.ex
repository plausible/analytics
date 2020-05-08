defmodule Plausible.Clickhouse do
  def insert_events(events) do
    insert = """
    INSERT INTO events (name, timestamp, domain, user_id, hostname, pathname, referrer, referrer_source, initial_referrer, initial_referrer_source, country_code, screen_size, browser, operating_system)
    VALUES
    """ <> String.duplicate(" (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),", length(events))

    args = Enum.reduce(events, [], fn event, acc ->
      [event.name, event.timestamp, event.domain, event.fingerprint, event.hostname, event.pathname, event.referrer, event.referrer_source, event.initial_referrer, event.initial_referrer_source, event.country_code, event.screen_size, event.browser, event.operating_system] ++ acc
    end)

    Clickhousex.query(:clickhouse, insert, args, log: {Plausible.Clickhouse, :log, []})
  end

  def insert_sessions(sessions) do
    insert = """
    INSERT INTO sessions (domain, user_id, hostname, start, is_bounce, entry_page, exit_page, referrer, referrer_source, country_code, screen_size, browser, operating_system)
    VALUES
    """ <> String.duplicate(" (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),", Enum.count(sessions))

    args = Enum.reduce(sessions, [], fn session, acc ->
      [session.domain, session.fingerprint, session.hostname, session.start, session.is_bounce && 1 || 0, session.entry_page, session.exit_page, session.referrer, session.referrer_source,session.country_code, session.screen_size, session.browser, session.operating_system] ++ acc
    end)

    Clickhousex.query(:clickhouse, insert, args, log: {Plausible.Clickhouse, :log, []})
  end

  @doc """
  Clickhouse does not support a standard DELETE operation. They do support a ALTER TABLE <table> DELETE WHERE ..;
  However, that query is async and we can't rely on the data being cleared for the next test. At the moment, this is
  the best way I've found to clear data but we have to hardcode the months(partitions) to delete.
  """
  def clear() do
    Clickhousex.query(:clickhouse, "ALTER TABLE events DROP PARTITION 201901", [], log: {Plausible.Clickhouse, :log, []})
    Clickhousex.query(:clickhouse, "ALTER TABLE sessions DROP PARTITION 201901", [], log: {Plausible.Clickhouse, :log, []})
  end

  def log(query) do
    require Logger
    timing = System.convert_time_unit(query.connection_time, :native, :millisecond)
    case query.result do
      {:ok, _q, _res} ->
        Logger.info("Clickhouse query OK db=#{timing}ms")
      {:error, e} ->
        Logger.error("Clickhouse query ERROR")
        Logger.error(inspect e)
    end

    Logger.debug(fn ->
      statement = String.replace(query.query.statement, "\n", " ")
      "#{statement} #{inspect query.params}"
    end)
  end

end
