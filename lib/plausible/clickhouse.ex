defmodule Plausible.Clickhouse do
  def all(query) do
    {q, params} = Ecto.Adapters.SQL.to_sql(:all, Plausible.Repo, query)
    q = String.replace(q, ~r/\$[0-9]+/, "?")
    res = Clickhousex.query!(:clickhouse, q, params, log: {Plausible.Clickhouse, :log, []})

    Enum.map(res.rows, fn row ->
      Enum.zip(res.columns, row)
      |> Enum.into(%{})
    end)
  end

  def insert_events(events) do
    insert =
      """
      INSERT INTO events (name, timestamp, domain, user_id, session_id, hostname, pathname, referrer, referrer_source, country_code, screen_size, browser, operating_system)
      VALUES
      """ <> String.duplicate(" (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),", length(events))

    args =
      Enum.reduce(events, [], fn event, acc ->
        [
          escape_quote(event.name),
          event.timestamp,
          event.domain,
          event.user_id,
          event.session_id,
          event.hostname,
          escape_quote(event.pathname),
          escape_quote(event.referrer || ""),
          escape_quote(event.referrer_source || ""),
          event.country_code || "",
          event.screen_size || "",
          event.browser || "",
          event.operating_system || ""
        ] ++ acc
      end)

    Clickhousex.query(:clickhouse, insert, args, log: {Plausible.Clickhouse, :log, []})
  end

  def insert_sessions(sessions) do
    insert =
      """
      INSERT INTO sessions (sign, session_id, domain, user_id, timestamp, hostname, start, is_bounce, entry_page, exit_page, events, pageviews, duration, referrer, referrer_source, country_code, screen_size, browser, operating_system)
      VALUES
      """ <>
        String.duplicate(
          " (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),",
          Enum.count(sessions)
        )

    args =
      Enum.reduce(sessions, [], fn session, acc ->
        [
          session.sign,
          session.session_id,
          session.domain,
          session.user_id,
          session.timestamp,
          session.hostname,
          session.start,
          (session.is_bounce && 1) || 0,
          escape_quote(session.entry_page),
          escape_quote(session.exit_page),
          session.events,
          session.pageviews,
          session.duration,
          escape_quote(session.referrer || ""),
          escape_quote(session.referrer_source || ""),
          session.country_code || "",
          session.screen_size || "",
          session.browser || "",
          session.operating_system || ""
        ] ++ acc
      end)

    Clickhousex.query(:clickhouse, insert, args, log: {Plausible.Clickhouse, :log, []})
  end

  def escape_quote(nil), do: nil
  def escape_quote(s), do: String.replace(s, "'", "''")

  def log(query) do
    require Logger

    case query.result do
      {:ok, _q, _res} ->
        timing = System.convert_time_unit(query.connection_time, :native, :millisecond)
        Logger.info("Clickhouse query OK db=#{timing}ms")

      e ->
        Logger.error("Clickhouse query ERROR")
        Logger.error(inspect(e))
    end

    Logger.debug(fn ->
      statement = String.replace(query.query.statement, "\n", " ")
      "#{statement} #{inspect(query.params)}"
    end)
  end
end
