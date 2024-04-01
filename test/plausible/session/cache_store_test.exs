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
        "meta.key": ["logged_in", "darkmode"],
        "meta.value": ["true", "false"]
      )

    session_params = %{
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
    }

    CacheStore.on_event(event, session_params, nil, buffer)

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
    assert session.referrer == Map.get(session_params, :referrer)
    assert session.referrer_source == Map.get(session_params, :referrer_source)
    assert session.utm_medium == Map.get(session_params, :utm_medium)
    assert session.utm_source == Map.get(session_params, :utm_source)
    assert session.utm_campaign == Map.get(session_params, :utm_campaign)
    assert session.utm_content == Map.get(session_params, :utm_content)
    assert session.utm_term == Map.get(session_params, :utm_term)
    assert session.country_code == Map.get(session_params, :country_code)
    assert session.screen_size == Map.get(session_params, :screen_size)
    assert session.operating_system == Map.get(session_params, :operating_system)
    assert session.operating_system_version == Map.get(session_params, :operating_system_version)
    assert session.browser == Map.get(session_params, :browser)
    assert session.browser_version == Map.get(session_params, :browser_version)
    assert session.timestamp == event.timestamp
    assert session.start === event.timestamp
    # assert Map.get(session, :"entry.meta.key") == ["logged_in", "darkmode"]
    # assert Map.get(session, :"entry.meta.value") == ["true", "false"]
  end

  test "updates session counters", %{buffer: buffer} do
    timestamp = Timex.now()
    event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -10))

    event2 = %{
      event1
      | timestamp: timestamp
    }

    CacheStore.on_event(event1, %{}, nil, buffer)
    CacheStore.on_event(event2, %{}, nil, buffer)
    assert_receive({WriteBuffer, :insert, [[_negative_record, session]]})
    assert session.is_bounce == false
    assert session.duration == 10
    assert session.pageviews == 2
    assert session.events == 2
  end

  describe "hostname-related attributes" do
    test "initial for non-pageview" do
      site_id = new_site_id()

      event =
        build(:event,
          name: "custom_event",
          site_id: site_id,
          pathname: "/path/1",
          hostname: "example.com"
        )

      flush([event])
      session = get_session(site_id)
      assert session.hostname == ""
      assert session.exit_page_hostname == ""
    end

    test "initial for pageview" do
      site_id = new_site_id()

      event =
        build(:event,
          name: "pageview",
          site_id: site_id,
          pathname: "/path/1",
          hostname: "example.com"
        )

      flush([event])
      session = get_session(site_id)
      assert session.hostname == "example.com"
      assert session.exit_page_hostname == "example.com"
    end

    test "subsequent pageview after custom_event" do
      site_id = new_site_id()

      events = [
        build(:event,
          name: "custom_event",
          site_id: site_id,
          pathname: "/path/1",
          hostname: "example.com",
          timestamp: Timex.shift(Timex.now(), seconds: -5)
        ),
        build(:event,
          name: "pageview",
          site_id: site_id,
          pathname: "/path/2",
          hostname: "example.com"
        )
      ]

      flush(events)
      session = get_session(site_id)
      assert session.hostname == "example.com"
      assert session.exit_page_hostname == "example.com"
    end

    test "hostname change" do
      site_id = new_site_id()

      events = [
        build(:event,
          name: "pageview",
          site_id: site_id,
          pathname: "/landing",
          hostname: "example.com",
          timestamp: Timex.shift(Timex.now(), seconds: -5)
        ),
        build(:event,
          name: "pageview",
          site_id: site_id,
          pathname: "/post/1",
          hostname: "blog.example.com"
        )
      ]

      flush(events)
      session = get_session(site_id)
      assert session.hostname == "blog.example.com"
      assert session.exit_page_hostname == "blog.example.com"
    end

    test "hostname change with custom event in the middle" do
      site_id = new_site_id()

      events = [
        build(:event,
          name: "pageview",
          site_id: site_id,
          pathname: "/landing",
          hostname: "example.com",
          timestamp: Timex.shift(Timex.now(), seconds: -5)
        ),
        build(:event,
          name: "custom_event",
          site_id: site_id,
          pathname: "/path/1",
          hostname: "analytics.example.com",
          timestamp: Timex.shift(Timex.now(), seconds: -3)
        ),
        build(:event,
          name: "pageview",
          site_id: site_id,
          pathname: "/post/1",
          hostname: "blog.example.com"
        )
      ]

      flush(events)
      session = get_session(site_id)
      assert session.hostname == "blog.example.com"
      assert session.exit_page_hostname == "blog.example.com"
    end
  end

  test "initial pageview-specific attributes" do
    site_id = new_site_id()

    event =
      build(:event,
        name: "custom_event",
        site_id: site_id,
        pathname: "/path/1",
        user_id: 1
      )

    flush([event])

    session = get_session(site_id)

    assert session.exit_page == ""
    assert session.events == 1
    assert session.pageviews == 0
  end

  test "updating pageview-specific attributes" do
    site_id = new_site_id()

    event1 =
      build(:event,
        name: "custom_event",
        site_id: site_id,
        pathname: "/path/1",
        user_id: 1
      )

    event2 =
      build(:pageview,
        pathname: "/path/2",
        site_id: site_id,
        user_id: 1
      )

    event3 =
      build(:pageview,
        pathname: "/path/3",
        site_id: site_id,
        user_id: 1
      )

    event4 =
      build(:event,
        name: "custom_event",
        site_id: site_id,
        pathname: "/path/4",
        user_id: 1
      )

    flush([event1, event2, event3, event4])

    session = get_session(site_id)

    assert session.entry_page == "/path/2"
    assert session.exit_page == "/path/3"
    assert session.events == 4
    assert session.pageviews == 2
  end

  test "calculates duration correctly for out-of-order events", %{buffer: buffer} do
    timestamp = Timex.now()
    event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: 10))

    event2 = %{event1 | timestamp: timestamp}

    CacheStore.on_event(event1, %{}, nil, buffer)
    CacheStore.on_event(event2, %{}, nil, buffer)

    assert_receive({WriteBuffer, :insert, [[_negative_record, session]]})
    assert session.duration == 10
  end

  describe "collapse order" do
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

      session = get_session(e.site_id)

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

  defp new_site_id() do
    [[site_id]] =
      Plausible.ClickhouseRepo.query!("select max(site_id) + rand() from sessions_v2 FINAL").rows

    site_id
  end

  defp flush(events) do
    for e <- events, do: CacheStore.on_event(e, %{}, nil)
    Plausible.Session.WriteBuffer.flush()
  end

  defp get_session(site_id) do
    session_q =
      from s in Plausible.ClickhouseSessionV2,
        where: s.site_id == ^site_id,
        order_by: [desc: :timestamp],
        limit: 1

    Plausible.ClickhouseRepo.one!(session_q)
  end
end
