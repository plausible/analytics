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
end
