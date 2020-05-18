defmodule Mix.Tasks.HydrateClickhouse do
  use Mix.Task
  use Plausible.Repo
  require Logger

  def run(args) do
    Application.ensure_all_started(:db_connection)
    Application.ensure_all_started(:hackney)
    clickhouse_config = Application.get_env(:plausible, :clickhouse)
    Clickhousex.start_link(Keyword.merge([scheme: :http, port: 8123, name: :clickhouse], clickhouse_config))
    Ecto.Migrator.with_repo(Plausible.Repo, fn repo ->
      execute(repo, args)
    end)
  end

  def execute(repo, _args \\ []) do
    create_events()
    create_sessions()
    hydrate_events(repo)
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
      session_id UUID,
      sign Int8,
      domain String,
      user_id FixedString(64),
      hostname String,
      timestamp DateTime,
      start DateTime,
      is_bounce UInt8,
      entry_page Nullable(String),
      exit_page Nullable(String),
      pageviews Int32,
      events Int32,
      duration UInt32,
      referrer Nullable(String),
      referrer_source Nullable(String),
      country_code Nullable(FixedString(2)),
      screen_size Nullable(String),
      operating_system Nullable(String),
      browser Nullable(String)
    ) ENGINE = CollapsingMergeTree(sign)
    PARTITION BY toYYYYMM(start)
    ORDER BY (domain, start, user_id, session_id)
    SETTINGS index_granularity = 8192
    """

    Clickhousex.query(:clickhouse, ddl, [])
    |> log
  end

  def chunk_query(queryable, chunk_size, repo) do
    chunk_stream = Stream.unfold(0, fn page_number ->
      offset = chunk_size * page_number
      page = from(
        q in queryable,
        offset: ^offset,
        limit: ^chunk_size
      ) |> repo.all(timeout: :infinity)
      {page, page_number + 1}
    end)
    Stream.take_while(chunk_stream, fn [] -> false; _ -> true end)
  end

  def escape_quote(s) do
    String.replace(s, "'", "''")
  end

  def hydrate_events(repo, _args \\ []) do
    event_chunks = from(e in Plausible.Event, where: e.domain == "plausible.io", order_by: e.id) |> chunk_query(10_000, repo)

    Enum.reduce(event_chunks, %{}, fn events, session_cache ->
      {session_cache, sessions} = Enum.reduce(events, {session_cache, []}, fn event, {session_cache, sessions} ->
        found_session = session_cache[event.fingerprint]
        active = is_active?(found_session, event)
        cond do
          found_session && active ->
            new_session = update_session(found_session, event)
            {
              Map.put(session_cache, event.fingerprint, new_session),
              [%{new_session | sign: 1}, %{found_session | sign: -1} | sessions]
            }
          found_session && !active ->
            new_session = new_session_from_event(event)
            {
              Map.put(session_cache, event.fingerprint, new_session),
              [new_session | sessions]
            }
          true ->
            new_session = new_session_from_event(event)
            {
              Map.put(session_cache, event.fingerprint, new_session),
              [new_session | sessions]
            }
        end
      end)

      Plausible.Clickhouse.insert_events(events)
      Plausible.Clickhouse.insert_sessions(sessions)
      session_cache
    end)
  end

  defp is_active?(session, event) do
    session && Timex.diff(event.timestamp, session.timestamp, :minute) <= 29
  end

  defp update_session(session, event) do
    %{session | timestamp: event.timestamp, exit_page: event.pathname, is_bounce: false, duration: Timex.diff(event.timestamp, session.start, :second), pageviews: (if event.name == "pageview", do: session.pageviews + 1, else: session.pageviews), events: session.events + 1}
  end

  defp new_session_from_event(event) do
    %Plausible.ClickhouseSession{
      sign: 1,
      session_id: UUID.uuid4(),
      hostname: event.hostname,
      domain: event.domain,
      user_id: event.fingerprint,
      entry_page: event.pathname,
      exit_page: event.pathname,
      is_bounce: true,
      duration: 0,
      pageviews: (if event.name == "pageview", do: 1, else: 0),
      events: 1,
      referrer: event.referrer,
      referrer_source: event.referrer_source,
      country_code: event.country_code,
      operating_system: event.operating_system,
      browser: event.browser,
      timestamp: event.timestamp,
      start: event.timestamp
    }
  end

  defp log({:ok, res}), do: Logger.info("#{inspect res}")
  defp log({:error, e}), do: Logger.error("[ERROR] #{inspect e}")
end
