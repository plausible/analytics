defmodule Plausible.Test.ClickhouseSetup do
  @conversion_1_session_id 123
  @conversion_2_session_id 234

  def run() do
    Plausible.TestUtils.create_events([
      %{
        name: "pageview",
        domain: "test-site.com",
        pathname: "/",
        country_code: "EE",
        browser: "Chrome",
        browser_version: "78.0",
        operating_system: "Mac",
        operating_system_version: "10.15",
        screen_size: "Desktop",
        referrer_source: "10words",
        referrer: "10words.com/page1",
        timestamp: ~N[2019-01-01 00:00:00],
        session_id: @conversion_1_session_id
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        pathname: "/",
        country_code: "EE",
        browser: "Chrome",
        browser_version: "78.0",
        operating_system: "Mac",
        operating_system_version: "10.15",
        screen_size: "Desktop",
        referrer_source: "10words",
        referrer: "10words.com/page2",
        timestamp: ~N[2019-01-01 00:00:00]
      },
      %{
        name: "pageview",
        domain: "test-site.com",
        pathname: "/",
        country_code: "US",
        browser: "Chrome",
        browser_version: "79.0",
        operating_system: "Mac",
        operating_system_version: "10.16",
        screen_size: "Laptop",
        referrer_source: "",
        referrer: "",
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
        timestamp: ~N[2019-01-01 01:00:00],
        "meta.key": ["variant"],
        "meta.value": ["A"]
      },
      %{
        name: "Signup",
        domain: "test-site.com",
        session_id: @conversion_1_session_id,
        timestamp: ~N[2019-01-01 02:00:00],
        "meta.key": ["variant"],
        "meta.value": ["B"]
      },
      %{
        name: "Signup",
        domain: "test-site.com",
        session_id: @conversion_2_session_id,
        timestamp: ~N[2019-01-01 02:00:00],
        "meta.key": ["variant"],
        "meta.value": ["B"]
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
        timestamp: ~N[2019-01-01 23:00:01]
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
      },
      %{
        name: "pageview",
        pathname: "/register",
        domain: "test-site.com",
        timestamp: ~N[2019-07-01 23:00:00]
      },
      %{
        name: "pageview",
        pathname: "/signup/new",
        domain: "test-site.com",
        timestamp: ~N[2019-07-01 23:00:00]
      },
      %{
        name: "pageview",
        pathname: "/billing/success",
        domain: "test-site.com",
        timestamp: ~N[2019-07-01 23:00:00]
      },
      %{
        name: "pageview",
        pathname: "/",
        domain: "test-site.com",
        timestamp: ~N[2019-07-01 23:00:00]
      },
      %{
        name: "pageview",
        pathname: "/reg",
        domain: "test-site.com",
        timestamp: ~N[2019-07-01 23:00:00]
      },
      %{
        name: "pageview",
        pathname: "/signup/new/2",
        domain: "test-site.com",
        timestamp: ~N[2019-07-01 23:00:00]
      },
      %{
        name: "pageview",
        pathname: "/signup/new/3",
        domain: "test-site.com",
        timestamp: ~N[2019-07-01 23:00:00]
      },
      %{
        name: "pageview",
        pathname: "/billing/upgrade/success",
        domain: "test-site.com",
        timestamp: ~N[2019-07-01 23:00:00]
      }
    ])

    Plausible.TestUtils.create_sessions([
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer_source: "10words",
        referrer: "10words.com/page1",
        utm_medium: "listing",
        country_code: "US",
        screen_size: "Desktop",
        browser: "Chrome",
        browser_version: "78.0",
        operating_system: "Mac",
        operating_system_version: "10.15",
        session_id: @conversion_1_session_id,
        is_bounce: true,
        duration: 100,
        start: ~N[2019-01-01 02:00:00],
        timestamp: ~N[2019-01-01 02:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer_source: "10words",
        referrer: "10words.com/page1",
        utm_medium: "listing",
        session_id: @conversion_2_session_id,
        is_bounce: false,
        duration: 0,
        start: ~N[2019-01-01 02:00:00],
        timestamp: ~N[2019-01-01 02:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer_source: "Bing",
        referrer: "",
        utm_medium: "search",
        is_bounce: false,
        duration: 100,
        start: ~N[2019-01-01 03:00:00],
        timestamp: ~N[2019-01-01 03:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer_source: "Google",
        referrer: "",
        is_bounce: false,
        start: ~N[2019-02-01 01:00:00],
        timestamp: ~N[2019-02-01 01:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer_source: "Google",
        referrer: "",
        is_bounce: false,
        start: ~N[2019-02-01 02:00:00],
        timestamp: ~N[2019-02-01 02:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer: "t.co/some-link",
        referrer_source: "Twitter",
        start: ~N[2019-03-01 01:00:00],
        timestamp: ~N[2019-03-01 01:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer: "t.co/some-link",
        referrer_source: "Twitter",
        start: ~N[2019-03-01 01:00:00],
        timestamp: ~N[2019-03-01 01:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer: "t.co/nonexistent-link",
        referrer_source: "Twitter",
        start: ~N[2019-03-01 02:00:00],
        timestamp: ~N[2019-03-01 02:00:00]
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/",
        referrer_source: "Bing",
        referrer: "bing.com",
        start: Timex.now() |> Timex.shift(minutes: -1),
        timestamp: Timex.now() |> Timex.shift(minutes: -1)
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/exit",
        referrer_source: "10words",
        referrer: "10words.com",
        start: Timex.now() |> Timex.shift(minutes: -2),
        timestamp: Timex.now() |> Timex.shift(minutes: -2)
      },
      %{
        domain: "test-site.com",
        entry_page: "/",
        exit_page: "/exit",
        referrer_source: "10words",
        referrer: "10words.com",
        start: Timex.now() |> Timex.shift(minutes: -3),
        timestamp: Timex.now() |> Timex.shift(minutes: -3)
      }
    ])
  end
end
