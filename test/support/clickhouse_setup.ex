defmodule Plausible.Test.ClickhouseSetup do
  def run() do
    create_events()
    create_sessions()
    load_fixtures()
  end

  def create_events() do
    drop = "DROP TABLE events"
    create = """
    CREATE TABLE events (
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

    Clickhousex.query(:clickhouse, drop, [],log: {Plausible.Clickhouse, :log, []})
    Clickhousex.query(:clickhouse, create, [],log: {Plausible.Clickhouse, :log, []})
  end

  def create_sessions() do
    drop = "DROP TABLE sessions"
    create = """
    CREATE TABLE sessions (
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
    ORDER BY (domain, start, user_id)
    SETTINGS index_granularity = 8192
    """

    Clickhousex.query(:clickhouse, drop, [],log: {Plausible.Clickhouse, :log, []})
    Clickhousex.query(:clickhouse, create, [],log: {Plausible.Clickhouse, :log, []})
  end

  def load_fixtures() do
    Plausible.TestUtils.create_events([
      %{name: "pageview", domain: "test-site.com", pathname: "/", country_code: "EE", browser: "Chrome", operating_system: "Mac", screen_size: "Desktop", referrer_source: "10words", referrer: "10words.com/page1", timestamp: ~N[2019-01-01 00:00:00]},
      %{name: "pageview", domain: "test-site.com", pathname: "/", country_code: "EE", browser: "Chrome", operating_system: "Mac", screen_size: "Desktop", referrer_source: "10words", referrer: "10words.com/page2", timestamp: ~N[2019-01-01 00:00:00]},
      %{name: "pageview", domain: "test-site.com", pathname: "/contact", country_code: "GB", browser: "Firefox", operating_system: "Android", screen_size: "Mobile", referrer_source: "Bing", timestamp: ~N[2019-01-01 00:00:00]},

      %{name: "pageview", domain: "test-site.com", timestamp: ~N[2019-01-31 00:00:00]},

      %{name: "Signup", domain: "test-site.com", initial_referrer_source: "Google", initial_referrer: "google.com/a", timestamp: ~N[2019-01-01 01:00:00]},
      %{name: "Signup", domain: "test-site.com", initial_referrer_source: "Google", initial_referrer: "google.com/a", timestamp: ~N[2019-01-01 02:00:00]},
      %{name: "Signup", domain: "test-site.com", initial_referrer_source: "Google", initial_referrer: "google.com/b", timestamp: ~N[2019-01-01 02:00:00]},

      %{name: "pageview", pathname: "/register", domain: "test-site.com", initial_referrer_source: "Google", initial_referrer: "google.com/a", timestamp: ~N[2019-01-01 23:00:00]},
      %{name: "pageview", pathname: "/register", domain: "test-site.com", initial_referrer_source: "Google", initial_referrer: "google.com/b", timestamp: ~N[2019-01-01 23:00:00]},
      %{name: "pageview", pathname: "/irrelevant", domain: "test-site.com", initial_referrer_source: "Google", initial_referrer: "google.com/b", timestamp: ~N[2019-01-01 23:00:00]},

      %{name: "pageview", domain: "test-site.com", referrer_source: "Google", timestamp: ~N[2019-02-01 01:00:00]},
      %{name: "pageview", domain: "test-site.com", referrer_source: "Google", timestamp: ~N[2019-02-01 02:00:00]},

      %{name: "pageview", domain: "test-site.com", referrer: "t.co/some-link", referrer_source: "Twitter", timestamp: ~N[2019-03-01 01:00:00]},
      %{name: "pageview", domain: "test-site.com", referrer: "t.co/some-link", referrer_source: "Twitter", timestamp: ~N[2019-03-01 01:00:00]},
      %{name: "pageview", domain: "test-site.com", referrer: "t.co/nonexistent-link", referrer_source: "Twitter", timestamp: ~N[2019-03-01 02:00:00]},

      %{name: "pageview", domain: "test-site.com"},
      %{name: "pageview", domain: "test-site.com", timestamp: Timex.now() |> Timex.shift(minutes: -3)},
      %{name: "pageview", domain: "test-site.com", timestamp: Timex.now() |> Timex.shift(minutes: -6)},

      %{name: "pageview", domain: "tz-test.com", timestamp: ~N[2019-01-01 00:00:00]},
      %{name: "pageview", domain: "public-site.io"}
    ])

    Plausible.TestUtils.create_sessions([
      %{domain: "test-site.com", entry_page: "/", referrer_source: "10words", referrer: "10words.com/page1", is_bounce: true, start: ~N[2019-01-01 02:00:00]},
      %{domain: "test-site.com", entry_page: "/", referrer_source: "10words", referrer: "10words.com/page1", is_bounce: false, start: ~N[2019-01-01 02:00:00]}
    ])
  end
end
