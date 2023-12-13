defmodule Plausible.Session.CacheStoreTest do
  use Plausible.DataCase
  alias Plausible.Session.CacheStore

  defmodule FakeBuffer do
    def insert(sessions) do
      send(self(), {WriteBuffer, :insert, [sessions]})
      {:ok, sessions}
    end
  end

  setup do
    [buffer: FakeBuffer]
  end

  test "creates a session from an event", %{buffer: buffer} do
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
        operating_system_version: "11",
        "meta.key": ["logged_in", "darkmode"],
        "meta.value": ["true", "false"]
      )

    CacheStore.on_event(event, nil, buffer)

    assert_receive({WriteBuffer, :insert, [sessions]})
    assert [session] = sessions
    assert session.hostname == event.hostname

    assert session.site_id == event.site_id

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
    # assert Map.get(session, :"entry.meta.key") == ["logged_in", "darkmode"]
    # assert Map.get(session, :"entry.meta.value") == ["true", "false"]
  end

  test "updates a session", %{buffer: buffer} do
    timestamp = Timex.now()
    event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -10))

    event2 = %{
      event1
      | timestamp: timestamp,
        country_code: "US",
        subdivision1_code: "SUB1",
        subdivision2_code: "SUB2",
        city_geoname_id: 12312,
        screen_size: "Desktop",
        operating_system: "Mac",
        operating_system_version: "11",
        browser: "Firefox",
        browser_version: "10"
    }

    CacheStore.on_event(event1, nil, buffer)
    CacheStore.on_event(event2, nil, buffer)
    assert_receive({WriteBuffer, :insert, [[_negative_record, session]]})
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

  test "calculates duration correctly for out-of-order events", %{buffer: buffer} do
    timestamp = Timex.now()
    event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: 10))

    event2 = %{event1 | timestamp: timestamp}

    CacheStore.on_event(event1, nil, buffer)
    CacheStore.on_event(event2, nil, buffer)

    assert_receive({WriteBuffer, :insert, [[_negative_record, session]]})
    assert session.duration == 10
  end

  describe "collapse order" do
    defp new_site_id() do
      [[site_id]] =
        Plausible.ClickhouseRepo.query!("select max(site_id) + rand() from sessions_v2 FINAL").rows

      site_id
    end

    defp flush(events) do
      for e <- events, do: CacheStore.on_event(e, nil)
      Plausible.Session.WriteBuffer.flush()
    end

    test "across parts" do
      e = build(:event, name: "pageview", site_id: new_site_id())

      flush([%{e | pathname: "/"}])
      flush([%{e | pathname: "/exit"}])

      session_q = from s in Plausible.ClickhouseSessionV2, where: s.site_id == ^e.site_id
      session = Plausible.ClickhouseRepo.one!(session_q, settings: [final: true])

      refute session.is_bounce
      assert session.entry_page == "/"
      assert session.exit_page == "/exit"
    end

    test "within parts" do
      e = build(:event, name: "pageview", site_id: new_site_id())

      flush([
        %{e | pathname: "/"},
        %{e | pathname: "/exit"}
      ])

      session_q = from s in Plausible.ClickhouseSessionV2, where: s.site_id == ^e.site_id
      session = Plausible.ClickhouseRepo.one!(session_q)

      refute session.is_bounce
      assert session.entry_page == "/"
      assert session.exit_page == "/exit"
    end

    test "across and within parts" do
      e = build(:event, name: "pageview", site_id: new_site_id())

      flush([
        %{e | pathname: "/"},
        %{e | pathname: "/about"}
      ])

      flush([
        %{e | pathname: "/login"},
        %{e | pathname: "/exit"}
      ])

      session_q = from s in Plausible.ClickhouseSessionV2, where: s.site_id == ^e.site_id
      session = Plausible.ClickhouseRepo.one!(session_q, settings: [final: true])

      refute session.is_bounce
      assert session.entry_page == "/"
      assert session.exit_page == "/exit"
      assert session.events == 4
    end
  end
end
