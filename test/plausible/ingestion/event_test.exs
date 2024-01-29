defmodule Plausible.Ingestion.EventTest do
  use Plausible.DataCase, async: true

  import Phoenix.ConnTest

  alias Plausible.Ingestion.Request
  alias Plausible.Ingestion.Event

  test "event pipeline processes a request into an event" do
    site = insert(:site)

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [_], dropped: []}} = Event.build_and_buffer(request)
  end

  test "event pipeline drops a request when site does not exists" do
    payload = %{
      name: "pageview",
      url: "http://dummy.site"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    assert dropped.drop_reason == :not_found
  end

  test "event pipeline drops a request when referrer is spam" do
    site = insert(:site)

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

  test "event pipeline drops a request when referrer is spam for multiple domains" do
    site = insert(:site)

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

  test "event pipeline selectively drops an event for multiple domains" do
    site = insert(:site)

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

  test "event pipeline selectively drops an event when rate-limited" do
    site = insert(:site, ingest_rate_limit_threshold: 1)

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

  test "event pipeline drops a request when header x-plausible-ip-type is dc_ip" do
    site = insert(:site)

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

  test "event pipeline drops events for site with accept_trafic_until in the past" do
    yesterday = Date.add(Date.utc_today(), -1)

    site =
      insert(:site,
        ingest_rate_limit_threshold: 1,
        members: [build(:user, accept_traffic_until: yesterday)]
      )

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

  @tag :full_build_only
  test "saves revenue amount" do
    site = insert(:site)
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
    site = insert(:site)

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
    _site = insert(:site, domain: "192.168.0.1")

    payload = %{
      name: "checkout",
      url: "http://192.168.0.1"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [event]}} = Event.build_and_buffer(request)
    assert event.clickhouse_event_attrs.hostname == "192.168.0.1"
  end

  test "Hostname is stored with public suffix processing" do
    _site = insert(:site, domain: "foo.netlify.app")

    payload = %{
      name: "checkout",
      url: "http://foo.netlify.app"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert {:ok, %{buffered: [event]}} = Event.build_and_buffer(request)
    assert event.clickhouse_event_attrs.hostname == "foo.netlify.app"
  end
end
