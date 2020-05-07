defmodule Mix.Tasks.HydrateClickhouse do
  use Mix.Task
  use Plausible.Repo
  require Logger

  def run(args) do
    Application.ensure_all_started(:plausible)
    execute(args)
  end

  def execute(_args \\ []) do
    create_events()
    create_sessions()
    hydrate_sessions()
    hydrate_events()
  end

  def create_events() do
    ddl = """
    CREATE TABLE IF NOT EXISTS events (
      timestamp DateTime,
      name String,
      domain String,
      user_id FixedString(64),
      hostname String,
      pathname String,
      referrer Nullable(String),
      referrer_source Nullable(String),
      initial_referrer Nullable(String),
      initial_referrer_source Nullable(String),
      country_code Nullable(FixedString(2)),
      screen_size Nullable(String),
      operating_system Nullable(String),
      browser Nullable(String)
    ) ENGINE = MergeTree()
    PARTITION BY toYYYYMM(timestamp)
    ORDER BY (name, domain, timestamp, user_id)
    SETTINGS index_granularity = 8192
    """

    Clickhousex.query(:clickhouse, ddl, [])
    |> log
  end

  def create_sessions() do
    ddl = """
    CREATE TABLE IF NOT EXISTS sessions (
      domain String,
      user_id FixedString(64),
      hostname String,
      start DateTime,
      is_bounce UInt8,
      entry_page Nullable(String),
      exit_page Nullable(String),
      referrer Nullable(String),
      referrer_source Nullable(String),
      country_code Nullable(FixedString(2)),
      screen_size Nullable(String),
      operating_system Nullable(String),
      browser Nullable(String)
    ) ENGINE = MergeTree()
    PARTITION BY toYYYYMM(start)
    ORDER BY (domain, start, user_id)
    SETTINGS index_granularity = 8192
    """

    Clickhousex.query(:clickhouse, ddl, [])
    |> log
  end

  def chunk_query(queryable, chunk_size) do
    chunk_stream = Stream.unfold(0, fn page_number ->
      offset = chunk_size * page_number
      page = from(
        q in queryable,
        offset: ^offset,
        limit: ^chunk_size
      ) |> Repo.all(timeout: :infinity)
      {page, page_number + 1}
    end)
    Stream.take_while(chunk_stream, fn [] -> false; _ -> true end)
  end

  def escape_quote(s) do
    String.replace(s, "'", "''")
  end

  def hydrate_events(_args \\ []) do
    event_chunks = from(e in Plausible.Event, order_by: e.id) |> chunk_query(10_000)

    for chunk <- event_chunks do
      insert = """
      INSERT INTO events (name, timestamp, domain, user_id, hostname, pathname, referrer, referrer_source, initial_referrer, initial_referrer_source, country_code, screen_size, browser, operating_system)
      VALUES
      """ <> String.duplicate(" (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),", Enum.count(chunk))

      args = Enum.reduce(chunk, [], fn event, acc ->
        acc ++ [event.name, event.timestamp, event.domain, event.fingerprint, event.hostname, escape_quote(event.pathname), event.referrer, event.referrer_source, event.initial_referrer, event.initial_referrer_source, event.country_code, event.screen_size, event.browser, event.operating_system]
      end)

      Clickhousex.query(:clickhouse, insert, args)
      |> log
    end
  end

  def hydrate_sessions(_args \\ []) do
    session_chunks = Repo.all(from e in Plausible.FingerprintSession, order_by: e.id) |> chunk_query(10_000)

    for chunk <- session_chunks do
      insert = """
      INSERT INTO sessions (domain, user_id, hostname, start, is_bounce, entry_page, exit_page, referrer, referrer_source, country_code, screen_size, browser, operating_system)
      VALUES
      """ <> String.duplicate(" (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?),", Enum.count(chunk))

      args = Enum.reduce(chunk, [], fn session, acc ->
        acc ++ [session.domain, session.fingerprint, session.hostname, session.start, session.is_bounce && 1 || 0, session.entry_page, session.exit_page, session.referrer, session.referrer_source,session.country_code, session.screen_size, session.browser, session.operating_system]
      end)

      Clickhousex.query(:clickhouse, insert, args)
      |> log
    end
  end

  defp log({:ok, res}), do: Logger.info("#{inspect res}")
  defp log({:error, e}), do: Logger.error("[ERROR] #{inspect e}")
end
