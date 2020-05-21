defmodule Mix.Tasks.HydrateClickhouse do
  use Mix.Task
  use Plausible.Repo
  require Logger
  @hash_key Keyword.fetch!(Application.get_env(:plausible, PlausibleWeb.Endpoint), :secret_key_base) |> binary_part(0, 16)

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
      user_id UInt64,
      session_id UInt64,
      hostname String,
      pathname String,
      referrer String,
      referrer_source String,
      initial_referrer String,
      initial_referrer_source String,
      country_code LowCardinality(FixedString(2)),
      screen_size LowCardinality(String),
      operating_system LowCardinality(String),
      browser LowCardinality(String)
    ) ENGINE = MergeTree()
    PARTITION BY toYYYYMM(timestamp)
    ORDER BY (name, domain, user_id, timestamp)
    SETTINGS index_granularity = 8192
    """

    Clickhousex.query(:clickhouse, ddl, [])
    |> log
  end

  def create_sessions() do
    ddl = """
    CREATE TABLE IF NOT EXISTS sessions (
      session_id UInt64,
      sign Int8,
      domain String,
      user_id UInt64,
      hostname String,
      timestamp DateTime,
      start DateTime,
      is_bounce UInt8,
      entry_page String,
      exit_page String,
      pageviews Int32,
      events Int32,
      duration UInt32,
      referrer String,
      referrer_source String,
      country_code LowCardinality(FixedString(2)),
      screen_size LowCardinality(String),
      operating_system LowCardinality(String),
      browser LowCardinality(String)
    ) ENGINE = CollapsingMergeTree(sign)
    PARTITION BY toYYYYMM(start)
    ORDER BY (domain, user_id, session_id, start)
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
    end_time = ~N[2020-05-21 10:46:51]
    total = Repo.aggregate(from(e in Plausible.Event, where: e.timestamp < ^end_time), :count, :id)

    event_chunks = from(
      e in Plausible.Event,
      where: e.timestamp < ^end_time,
      order_by: e.id
    ) |> chunk_query(50_000, repo)

    Enum.reduce(event_chunks, {%{}, 0}, fn events, {session_cache, processed_events} ->
      {session_cache, sessions, events} = Enum.reduce(events, {session_cache, [], []}, fn event, {session_cache, sessions, new_events} ->
        found_session = session_cache[event.fingerprint]
        active = is_active?(found_session, event)
        user_id = SipHash.hash!(@hash_key, event.fingerprint)
        clickhouse_event = struct(Plausible.ClickhouseEvent, Map.from_struct(event) |> Map.put(:user_id, user_id))

        cond do
          found_session && active ->
            new_session = update_session(found_session, clickhouse_event)
            {
              Map.put(session_cache, event.fingerprint, new_session),
              [%{new_session | sign: 1}, %{found_session | sign: -1} | sessions],
              new_events ++ [%{clickhouse_event | session_id: new_session.session_id}]
            }
          found_session && !active ->
            new_session = new_session_from_event(clickhouse_event)
            {
              Map.put(session_cache, event.fingerprint, new_session),
              [new_session | sessions],
              new_events ++ [%{clickhouse_event | session_id: new_session.session_id}]
            }
          true ->
            new_session = new_session_from_event(clickhouse_event)
            {
              Map.put(session_cache, event.fingerprint, new_session),
              [new_session | sessions],
              new_events ++ [%{clickhouse_event | session_id: new_session.session_id}]
            }
        end
      end)

      Plausible.Clickhouse.insert_events(events)
      Plausible.Clickhouse.insert_sessions(sessions)
      session_cache = clean(session_cache, List.last(events).timestamp)
      new_processed_count = processed_events + Enum.count(events)
      IO.puts("Processed #{new_processed_count} out of #{total} (#{round(new_processed_count / total * 100)}%)")
      {session_cache, processed_events + Enum.count(events)}
    end)
  end

  defp clean(session_cache, latest_timestamp) do
     cleaned = Enum.reduce(session_cache, %{}, fn {key, session}, acc ->
      if Timex.diff(latest_timestamp, session.timestamp, :second) <= 3600 do
        Map.put(acc, key, session)
      else
        acc # forget the session
      end
    end)

    n_old = Enum.count(session_cache)
    n_new = Enum.count(cleaned)

    IO.puts("Removed #{n_old - n_new} sessions from store")
    cleaned
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
      session_id: Plausible.ClickhouseSession.random_uint64(),
      hostname: event.hostname,
      domain: event.domain,
      user_id: event.user_id,
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
