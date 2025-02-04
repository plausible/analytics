defmodule Plausible.Session.CacheStoreTest do
  use Plausible.DataCase

  alias Plausible.Session.CacheStore

  @session_params %{
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

  setup do
    current_pid = self()

    buffer = fn sessions ->
      send(current_pid, {:buffer, :insert, [sessions]})
      {:ok, sessions}
    end

    slow_buffer = fn sessions ->
      Process.sleep(200)
      send(current_pid, {:slow_buffer, :insert, [sessions]})
      {:ok, sessions}
    end

    [buffer: buffer, slow_buffer: slow_buffer]
  end

  test "event processing is sequential within session", %{
    buffer: buffer,
    slow_buffer: slow_buffer,
    test: test
  } do
    telemetry_event = CacheStore.lock_telemetry_event()

    :telemetry.attach(
      "#{test}-telemetry-handler",
      telemetry_event,
      fn ^telemetry_event, %{duration: d}, _, _ when is_integer(d) ->
        send(self(), {:telemetry_handled, d})
      end,
      %{}
    )

    event1 = build(:event, name: "pageview")
    event2 = build(:event, name: "pageview", user_id: event1.user_id, site_id: event1.site_id)
    event3 = build(:event, name: "pageview", user_id: event1.user_id, site_id: event1.site_id)

    CacheStore.on_event(event1, @session_params, nil, buffer)

    assert_receive({:buffer, :insert, [[session1]]})
    assert_receive({:telemetry_handled, duration})
    assert is_integer(duration)

    [event2, event3]
    |> Enum.map(fn e ->
      Task.async(fn ->
        CacheStore.on_event(e, @session_params, nil, slow_buffer)
      end)
    end)
    |> Task.await_many()

    assert_receive({:slow_buffer, :insert, [[removed_session11, updated_session12]]})
    assert_receive({:slow_buffer, :insert, [[removed_session12, updated_session13]]})

    # Without isolation enforced in `CacheStore.on_event/4`,
    # event2 and event3 would both get executed in parallel
    # and treat event1 as event to be updated. This would result
    # in a following set of entries in Clickhouse sessions
    # table for _the same_ session:
    #
    #             session_id | is_bounce | sign
    # (event1)      123           1         1
    # (event2)      123           1         -1
    #               123           0         1
    # (event3)      123           1         -1
    #               123           0         1
    #
    # Once collapsing merge tree table does collapsing, we'd end up with:
    #
    # session_id | is_bounce | sign
    #   123           0         1
    #   123           1         -1
    #   123           0         1
    #
    # This in turn led to sum(sign * is_bounce) < 0 which, after underflowed casting,
    # ended up with 2^32-(small n) for bounce_rate value.

    assert removed_session11 == %{session1 | sign: -1}
    assert updated_session12.sign == 1
    assert updated_session12.events == 2
    assert updated_session12.pageviews == 2
    assert removed_session12 == %{updated_session12 | sign: -1}
    assert updated_session13.sign == 1
    assert updated_session13.events == 3
    assert updated_session13.pageviews == 3
  end

  @tag :slow
  test "in case of lock kicking in, the slow event finishes processing", %{buffer: buffer} do
    current_pid = self()

    very_slow_buffer = fn sessions ->
      Process.sleep(1000)
      send(current_pid, {:very_slow_buffer, :insert, [sessions]})
      {:ok, sessions}
    end

    event1 = build(:event, name: "pageview")
    event2 = build(:event, name: "pageview", user_id: event1.user_id, site_id: event1.site_id)
    event3 = build(:event, name: "pageview", user_id: event1.user_id, site_id: event1.site_id)

    async1 =
      Task.async(fn ->
        CacheStore.on_event(event1, @session_params, nil, very_slow_buffer)
      end)

    # Ensure next events are executed after processing event1 starts
    Process.sleep(100)

    async2 =
      Task.async(fn ->
        CacheStore.on_event(event2, @session_params, nil, buffer)
      end)

    async3 =
      Task.async(fn ->
        CacheStore.on_event(event3, @session_params, nil, buffer)
      end)

    Task.await_many([async1, async2, async3])

    assert_receive({:very_slow_buffer, :insert, [[_session]]})
    refute_receive({:buffer, :insert, [[_updated_session]]})
  end

  @tag :slow
  test "lock on slow processing of one event does not affect unrelated events", %{buffer: buffer} do
    current_pid = self()

    very_slow_buffer = fn sessions ->
      Process.sleep(1000)
      send(current_pid, {:very_slow_buffer, :insert, [sessions]})
      {:ok, sessions}
    end

    event1 = build(:event, name: "pageview")
    event2 = build(:event, name: "pageview")
    event3 = build(:event, name: "pageview", user_id: event2.user_id, site_id: event2.site_id)

    async1 =
      Task.async(fn ->
        CacheStore.on_event(event1, @session_params, nil, very_slow_buffer)
      end)

    # Ensure next events are executed after processing event1 starts
    Process.sleep(100)

    async2 =
      Task.async(fn ->
        CacheStore.on_event(event2, @session_params, nil, buffer)
      end)

    Process.sleep(100)

    async3 =
      Task.async(fn ->
        CacheStore.on_event(event3, @session_params, nil, buffer)
      end)

    Task.await_many([async1, async2, async3])

    assert_receive({:very_slow_buffer, :insert, [[_slow_session]]})
    assert_receive({:buffer, :insert, [[new_session1]]})
    assert_receive({:buffer, :insert, [[removed_session1, updated_session1]]})
    assert new_session1.sign == 1
    assert removed_session1.session_id == new_session1.session_id
    assert removed_session1.sign == -1
    assert updated_session1.session_id == removed_session1.session_id
    assert updated_session1.sign == 1
  end

  test "exploding event processing is passed through by locking mechanism" do
    crashing_buffer = fn _sessions ->
      raise "boom"
    end

    event = build(:event, name: "pageview")

    assert_raise RuntimeError, "boom", fn ->
      CacheStore.on_event(event, @session_params, nil, crashing_buffer)
    end
  end

  test "creates a session from an event", %{buffer: buffer} do
    event =
      build(:event,
        name: "pageview",
        "meta.key": ["logged_in", "darkmode"],
        "meta.value": ["true", "false"]
      )

    CacheStore.on_event(event, @session_params, nil, buffer)

    assert_receive({:buffer, :insert, [sessions]})
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
    assert session.referrer == Map.get(@session_params, :referrer)
    assert session.referrer_source == Map.get(@session_params, :referrer_source)
    assert session.utm_medium == Map.get(@session_params, :utm_medium)
    assert session.utm_source == Map.get(@session_params, :utm_source)
    assert session.utm_campaign == Map.get(@session_params, :utm_campaign)
    assert session.utm_content == Map.get(@session_params, :utm_content)
    assert session.utm_term == Map.get(@session_params, :utm_term)
    assert session.country_code == Map.get(@session_params, :country_code)
    assert session.screen_size == Map.get(@session_params, :screen_size)
    assert session.operating_system == Map.get(@session_params, :operating_system)
    assert session.operating_system_version == Map.get(@session_params, :operating_system_version)
    assert session.browser == Map.get(@session_params, :browser)
    assert session.browser_version == Map.get(@session_params, :browser_version)
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
    assert_receive({:buffer, :insert, [[_negative_record, session]]})
    assert session.is_bounce == false
    assert session.duration == 10
    assert session.pageviews == 2
    assert session.events == 2
  end

  test "does not update session counters on engagement event", %{buffer: buffer} do
    now = Timex.now()
    pageview = build(:pageview, timestamp: Timex.shift(now, seconds: -10))
    engagement = %{pageview | name: "engagement", timestamp: now}

    CacheStore.on_event(pageview, %{}, nil, buffer)
    CacheStore.on_event(engagement, %{}, nil, buffer)
    assert_receive({:buffer, :insert, [[session]]})

    assert session.is_bounce == true
    assert session.duration == 0
    assert session.pageviews == 1
    assert session.events == 1
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
          hostname: "whatever.example.com",
          timestamp: Timex.shift(Timex.now(), seconds: -5),
          user_id: 1
        ),
        build(:event,
          name: "pageview",
          site_id: site_id,
          pathname: "/path/2",
          hostname: "example.com",
          user_id: 1
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
          timestamp: Timex.shift(Timex.now(), seconds: -5),
          user_id: 1
        ),
        build(:event,
          name: "pageview",
          site_id: site_id,
          pathname: "/post/1",
          hostname: "blog.example.com",
          user_id: 1
        )
      ]

      flush(events)
      session = get_session(site_id)
      assert session.hostname == "example.com"
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
          timestamp: Timex.shift(Timex.now(), seconds: -5),
          user_id: 1
        ),
        build(:event,
          name: "custom_event",
          site_id: site_id,
          pathname: "/path/1",
          hostname: "analytics.example.com",
          timestamp: Timex.shift(Timex.now(), seconds: -3),
          user_id: 1
        ),
        build(:event,
          name: "pageview",
          site_id: site_id,
          pathname: "/post/1",
          hostname: "blog.example.com",
          user_id: 1
        )
      ]

      flush(events)
      session = get_session(site_id)
      assert session.hostname == "example.com"
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

    assert_receive({:buffer, :insert, [[_negative_record, session]]})
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
