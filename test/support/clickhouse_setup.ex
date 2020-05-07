defmodule Plausible.Test.ClickhouseSetup do
  def run() do
    create_events()
    create_sessions()
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

    Clickhousex.query(:clickhouse, ddl, [],log: {Plausible.Clickhouse, :log, []})
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

    Clickhousex.query(:clickhouse, ddl, [],log: {Plausible.Clickhouse, :log, []})
  end
end
