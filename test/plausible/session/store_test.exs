defmodule Plausible.Session.StoreTest do
  use Plausible.DataCase
  import Double
  alias Plausible.Session.{Store, WriteBuffer}

  setup do
    buffer =
      WriteBuffer
      |> stub(:insert, fn _sessions -> nil end)

    {:ok, store} = GenServer.start_link(Store, buffer: buffer)
    [store: store, buffer: buffer]
  end

  test "creates a session from an event", %{store: store} do
    event =
      build(:event,
        name: "pageview",
        referrer: "ref",
        referrer_source: "refsource",
        utm_medium: "medium",
        utm_source: "source",
        utm_campaign: "campaign",
        utm_content: "content",
        utm_term: "term",
        browser: "browser",
        browser_version: "55",
        country_code: "EE",
        screen_size: "Desktop",
        operating_system: "Mac",
        operating_system_version: "11"
      )

    Store.on_event(event, nil, store)

    assert_receive({WriteBuffer, :insert, [sessions]})
    assert [session] = sessions
    assert session.hostname == event.hostname
    assert session.domain == event.domain
    assert session.user_id == event.user_id
    assert session.entry_page == event.pathname
    assert session.exit_page == event.pathname
    assert session.is_bounce == true
    assert session.duration == 0
    assert session.pageviews == 1
    assert session.events == 1
    assert session.referrer == event.referrer
    assert session.referrer_source == event.referrer_source
    assert session.utm_medium == event.utm_medium
    assert session.utm_source == event.utm_source
    assert session.utm_campaign == event.utm_campaign
    assert session.utm_content == event.utm_content
    assert session.utm_term == event.utm_term
    assert session.country_code == event.country_code
    assert session.screen_size == event.screen_size
    assert session.operating_system == event.operating_system
    assert session.operating_system_version == event.operating_system_version
    assert session.browser == event.browser
    assert session.browser_version == event.browser_version
    assert session.timestamp == event.timestamp
    assert session.start === event.timestamp
  end

  test "updates a session", %{store: store} do
    timestamp = Timex.now()
    event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -10))

    event2 =
      build(:event,
        domain: event1.domain,
        user_id: event1.user_id,
        name: "pageview",
        timestamp: timestamp,
        country_code: "US",
        subdivision1_code: "SUB1",
        subdivision2_code: "SUB2",
        city_geoname_id: 12312,
        screen_size: "Desktop",
        operating_system: "Mac",
        operating_system_version: "11",
        browser: "Firefox",
        browser_version: "10"
      )

    Store.on_event(event1, nil, store)
    Store.on_event(event2, nil, store)
    assert_receive({WriteBuffer, :insert, [[session, _negative_record]]})
    assert session.is_bounce == false
    assert session.duration == 10
    assert session.pageviews == 2
    assert session.events == 2
    assert session.country_code == "US"
    assert session.subdivision1_code == "SUB1"
    assert session.subdivision2_code == "SUB2"
    assert session.city_geoname_id == 12312
    assert session.operating_system == "Mac"
    assert session.operating_system_version == "11"
    assert session.browser == "Firefox"
    assert session.browser_version == "10"
    assert session.screen_size == "Desktop"
  end

  test "calculates duration correctly for out-of-order events", %{store: store} do
    timestamp = Timex.now()
    event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: 10))

    event2 =
      build(:event,
        domain: event1.domain,
        user_id: event1.user_id,
        name: "pageview",
        timestamp: timestamp
      )

    Store.on_event(event1, nil, store)
    Store.on_event(event2, nil, store)

    assert_receive({WriteBuffer, :insert, [[session, _negative_record]]})
    assert session.duration == 10
  end
end
