defmodule Plausible.Ingestion.EventTest do
  use Plausible.DataCase, async: false
  use Plausible.Teams.Test

  import Phoenix.ConnTest

  alias Plausible.Ingestion.Request
  alias Plausible.Ingestion.Event

  test "processes a request into an event" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [_], dropped: []}} = Event.build_and_buffer(request)
  end

  @regressive_user_agents [
    ~s|Mozilla/5.0 (Macintosh; Intel Mac OS X 13_2_1) AppleWebKit/537.3666 (KHTML, like Gecko) Chrome/110.0.0.0.0 Safari/537.3666|,
    ~s|Mozilla/5.0 (Linux; arm_64; Android 10; Mi Note 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.5765.05 Mobile Safari/537.36|
  ]

  for {user_agent, idx} <- Enum.with_index(@regressive_user_agents) do
    test "processes user agents known to cause problems parsing in the past (case #{idx})" do
      site = new_site()

      payload = %{
        name: "pageview",
        url: "http://#{site.domain}"
      }

      conn =
        build_conn(:post, "/api/events", payload)
        |> Plug.Conn.put_req_header("user-agent", unquote(user_agent))

      assert {:ok, request} = Request.build(conn)

      assert {:ok, %{buffered: [_], dropped: []}} = Event.build_and_buffer(request)
    end
  end

  test "times out parsing user agent", %{test: test} do
    on_exit(:detach, fn ->
      :telemetry.detach("ua-timeout-#{test}")
    end)

    test_pid = self()
    event = Event.telemetry_ua_parse_timeout()

    :telemetry.attach(
      "ua-timeout-#{test}",
      event,
      fn ^event, _, _, _ ->
        send(test_pid, :telemetry_handled)
      end,
      %{}
    )

    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}"
    }

    conn =
      :post
      |> build_conn("/api/events", payload)
      |> Plug.Conn.put_req_header("user-agent", :binary.copy("a", 1024 * 8))

    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [_], dropped: []}} = Event.build_and_buffer(request)
    assert_receive :telemetry_handled
  end

  test "drops installation support user agent" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}"
    }

    conn =
      build_conn(:post, "/api/events", payload)
      |> Plug.Conn.put_req_header("user-agent", Plausible.InstallationSupport.user_agent())

    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :verification_agent
  end

  test "drops a request when site does not exists" do
    payload = %{
      name: "pageview",
      url: "http://dummy.site"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :not_found
  end

  test "drops a request when referrer is spam" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      referrer: "https://www.1-best-seo.com",
      domain: site.domain
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :spam_referrer
  end

  test "drops a request when referrer is spam for multiple domains" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      referrer: "https://www.1-best-seo.com",
      d: "#{site.domain},#{site.domain}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{dropped: [dropped, dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :spam_referrer
  end

  test "selectively drops an event for multiple domains" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      d: "#{site.domain},thisdoesnotexist.com"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [_], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :not_found
  end

  test "selectively drops an event when rate-limited" do
    site = new_site(ingest_rate_limit_threshold: 1)

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      d: "#{site.domain}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [_], dropped: []}} = Event.build_and_buffer(request)
    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :throttle
  end

  test "drops a request when header x-plausible-ip-type is dc_ip" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      domain: site.domain
    }

    conn = build_conn(:post, "/api/events", payload)
    conn = Plug.Conn.put_req_header(conn, "x-plausible-ip-type", "dc_ip")
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :dc_ip
  end

  test "drops a request when ip is on blocklist" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      domain: site.domain
    }

    conn = build_conn(:post, "/api/events", payload)
    conn = %{conn | remote_ip: {127, 7, 7, 7}}

    {:ok, _} = Plausible.Shields.add_ip_rule(site, %{"inet" => "127.7.7.7"})

    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :site_ip_blocklist
  end

  test "drops a request when country is on blocklist" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      domain: site.domain
    }

    conn = build_conn(:post, "/api/events", payload)
    conn = %{conn | remote_ip: {216, 160, 83, 56}}

    %{country_code: cc} = Plausible.Ingestion.Geolocation.lookup("216.160.83.56")
    {:ok, _} = Plausible.Shields.add_country_rule(site, %{"country_code" => cc})

    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :site_country_blocklist
  end

  test "drops a request when page is on blocklist" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://dummy.site/blocked/page",
      domain: site.domain
    }

    conn = build_conn(:post, "/api/events", payload)

    {:ok, _} = Plausible.Shields.add_page_rule(site, %{"page_path" => "/blocked/**"})

    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :site_page_blocklist
  end

  test "drops a request when hostname allowlist is defined and hostname is not on the list" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      domain: site.domain
    }

    conn = build_conn(:post, "/api/events", payload)

    {:ok, _} = Plausible.Shields.add_hostname_rule(site, %{"hostname" => "subdomain.dummy.site"})

    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :site_hostname_allowlist
  end

  test "passes a request when hostname allowlist is defined and hostname is on the list" do
    site = new_site()

    payload = %{
      name: "pageview",
      url: "http://subdomain.dummy.site",
      domain: site.domain
    }

    conn = build_conn(:post, "/api/events", payload)

    {:ok, _} = Plausible.Shields.add_hostname_rule(site, %{"hostname" => "subdomain.dummy.site"})

    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [_], dropped: []}} = Event.build_and_buffer(request)
  end

  test "drops events for site with accept_trafic_until in the past" do
    yesterday = Date.add(Date.utc_today(), -1)

    owner = new_user(team: [accept_traffic_until: yesterday])
    site = new_site(ingest_rate_limit_threshold: 1, owner: owner)

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      d: "#{site.domain}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :payment_required
  end

  @tag :slow
  test "drops events on session lock timeout" do
    site = new_site()

    test = self()

    very_slow_buffer = fn _sessions ->
      send(test, :slow_buffer_insert_started)
      Process.sleep(800)
    end

    first_conn =
      build_conn(:post, "/api/events", %{
        name: "pageview",
        url: "http://dummy.site",
        d: "#{site.domain}"
      })

    assert {:ok, first_request} = Request.build(first_conn)

    second_conn =
      build_conn(:post, "/api/events", %{
        name: "page_scrolled",
        url: "http://dummy.site",
        d: "#{site.domain}"
      })

    assert {:ok, second_request} = Request.build(second_conn)

    Task.start(fn ->
      assert {:ok, %{buffered: [_event], dropped: []}} =
               Event.build_and_buffer(first_request,
                 persistor_opts: [session_write_buffer_insert: very_slow_buffer]
               )
    end)

    receive do
      :slow_buffer_insert_started ->
        assert {:ok, %{buffered: [], dropped: [dropped]}} =
                 Event.build_and_buffer(second_request,
                   persistor_opts: [session_write_buffer_insert: very_slow_buffer]
                 )

        assert dropped.drop_reason == :lock_timeout
    end
  end

  test "drops engagement event when no session found from cache" do
    site = new_site()

    payload = %{
      name: "engagement",
      url: "https://#{site.domain}/123",
      d: "#{site.domain}",
      sd: 25,
      et: 1000
    }

    conn = build_conn(:post, "/api/events", payload)

    assert {:ok, request} = Request.build(conn)
    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :no_session_for_engagement
  end

  @tag :ee_only
  test "saves revenue amount" do
    site = new_site()
    _goal = insert(:goal, event_name: "checkout", currency: "USD", site: site)

    payload = %{
      name: "checkout",
      url: "http://#{site.domain}",
      revenue: %{amount: 10.2, currency: "USD"}
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [event], dropped: []}} = Event.build_and_buffer(request)
    assert Decimal.eq?(event.clickhouse_event.revenue_source_amount, Decimal.new("10.2"))
  end

  test "does not save revenue amount when there is no revenue goal" do
    site = new_site()

    payload = %{
      name: "checkout",
      url: "http://#{site.domain}",
      revenue: %{amount: 10.2, currency: "USD"}
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [event], dropped: []}} = Event.build_and_buffer(request)
    assert event.clickhouse_event.revenue_source_amount == nil
  end

  test "IPv4 hostname is stored without public suffix processing" do
    _site = new_site(domain: "192.168.0.1")

    payload = %{
      name: "checkout",
      url: "http://192.168.0.1"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [event]}} = Event.build_and_buffer(request)
    assert event.clickhouse_event.hostname == "192.168.0.1"
  end

  test "Hostname is stored with public suffix processing" do
    _site = new_site(domain: "foo.netlify.app")

    payload = %{
      name: "checkout",
      url: "http://foo.netlify.app"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [event]}} = Event.build_and_buffer(request)
    assert event.clickhouse_event.hostname == "foo.netlify.app"
  end

  test "hostname is (none) when no hostname can be derived from the url" do
    site = new_site(domain: "foo.example.com")

    payload = %{
      domain: site.domain,
      name: "pageview",
      url: "/no/hostname"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [event]}} = Event.build_and_buffer(request)
    assert event.clickhouse_event.hostname == "(none)"
  end
end
