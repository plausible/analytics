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
      user_id UInt64,
      session_id UInt64,
      hostname String,
      pathname String,
      referrer String,
      referrer_source String,
      country_code LowCardinality(FixedString(2)),
      screen_size LowCardinality(String),
      operating_system LowCardinality(String),
      browser LowCardinality(String)
    ) ENGINE = MergeTree()
    PARTITION BY toYYYYMM(timestamp)
    ORDER BY (name, domain, user_id, timestamp)
    SETTINGS index_granularity = 8192
    """

    Clickhousex.query(:clickhouse, drop, [], log: {Plausible.Clickhouse, :log, []})
    Clickhousex.query(:clickhouse, create, [], log: {Plausible.Clickhouse, :log, []})
  end

  def create_sessions() do
    drop = "DROP TABLE sessions"

    create = """
    CREATE TABLE sessions (
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

    Clickhousex.query(:clickhouse, drop, [], log: {Plausible.Clickhouse, :log, []})
    Clickhousex.query(:clickhouse, create, [], log: {Plausible.Clickhouse, :log, []})
  end

  @conversion_1_session_id 123
  @conversion_2_session_id 234

  def load_fixtures() do
    Plausible.TestUtils.create_events([
      %{
        name: "pageview",
        domain: "test-site.com",
        pathname: "/",
        country_code: "EE",
        browser: "Chrome",
        operating_system: "Mac",
        screen_size: "Desktop",
        referrer_source: "10words",
        referrer: "10words.com/page1",
        timestamp: ~N[2019-01-01 00:00:00]
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        pathname: "/",
        country_code: "EE",
        browser: "Chrome",
        operating_system: "Mac",
        screen_size: "Desktop",
        referrer_source: "10words",
        referrer: "10words.com/page2",
        timestamp: ~N[2019-01-01 00:00:00]
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        pathname: "/contact",
        country_code: "GB",
        browser: "Firefox",
        operating_system: "Android",
        screen_size: "Mobile",
        referrer_source: "Bing",
        timestamp: ~N[2019-01-01 00:00:00]
      },
      %{name: "pageview", domain: "test-site.com", timestamp: ~N[2019-01-31 00:00:00]},
      %{
        name: "Signup",
        domain: "test-site.com",
        session_id: @conversion_1_session_id,
        timestamp: ~N[2019-01-01 01:00:00]
      },
      %{
        name: "Signup",
        domain: "test-site.com",
        session_id: @conversion_1_session_id,
        timestamp: ~N[2019-01-01 02:00:00]
      },
      %{
        name: "Signup",
        domain: "test-site.com",
        session_id: @conversion_2_session_id,
        timestamp: ~N[2019-01-01 02:00:00]
      },
      %{
        name: "pageview",
        pathname: "/register",
        domain: "test-site.com",
        session_id: @conversion_1_session_id,
        timestamp: ~N[2019-01-01 23:00:00]
      },
      %{
        name: "pageview",
        pathname: "/register",
        domain: "test-site.com",
        session_id: @conversion_2_session_id,
        timestamp: ~N[2019-01-01 23:00:00]
      },
      %{
        name: "pageview",
        pathname: "/irrelevant",
        domain: "test-site.com",
        session_id: @conversion_1_session_id,
        timestamp: ~N[2019-01-01 23:00:00]
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        referrer_source: "Google",
        timestamp: ~N[2019-02-01 01:00:00]
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        referrer_source: "Google",
        timestamp: ~N[2019-02-01 02:00:00]
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        referrer: "t.co/some-link",
        referrer_source: "Twitter",
        timestamp: ~N[2019-03-01 01:00:00]
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        referrer: "t.co/some-link",
        referrer_source: "Twitter",
        timestamp: ~N[2019-03-01 01:00:00]
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        referrer: "t.co/nonexistent-link",
        referrer_source: "Twitter",
        timestamp: ~N[2019-03-01 02:00:00]
      },
      %{name: "pageview", domain: "test-site.com"},
      %{
        name: "pageview",
        domain: "test-site.com",
        timestamp: Timex.now() |> Timex.shift(minutes: -3)
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        timestamp: Timex.now() |> Timex.shift(minutes: -6)
      },
      %{name: "pageview", domain: "tz-test.com", timestamp: ~N[2019-01-01 00:00:00]},
      %{name: "pageview", domain: "public-site.io"},
      %{
        name: "pageview",
        domain: "fetch-tweets-test.com",
        referrer: "t.co/a-link",
        referrer_source: "Twitter"
      },
      %{
        name: "pageview",
        domain: "fetch-tweets-test.com",
        referrer: "t.co/b-link",
        referrer_source: "Twitter",
        timestamp: Timex.now() |> Timex.shift(days: -5)
      }
    ])

    Plausible.TestUtils.create_sessions([
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer_source: "10words",
        referrer: "10words.com/page1",
        session_id: @conversion_1_session_id,
        is_bounce: true,
        start: ~N[2019-01-01 02:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer_source: "10words",
        referrer: "10words.com/page1",
        session_id: @conversion_2_session_id,
        is_bounce: false,
        start: ~N[2019-01-01 02:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer_source: "Bing",
        referrer: "",
        is_bounce: false,
        start: ~N[2019-01-01 03:00:00]
      }
    ])
  end
end
