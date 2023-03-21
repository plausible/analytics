defmodule Plausible.Ingestion.RequestTest do
  use Plausible.DataCase, async: true

  import Phoenix.ConnTest
  import Plug.Conn

  alias Plausible.Ingestion.Request

  test "request cannot be built from conn without payload" do
    conn = build_conn(:post, "/api/events", %{})
    assert {:error, changeset} = Request.build(conn)

    errors = Keyword.keys(changeset.errors)
    assert :event_name in errors
    assert :domain in errors
    assert :url in errors
  end

  test "request cannot be built from non-json payload" do
    conn = build_conn(:post, "/api/events", "defnotjson")
    assert {:error, changeset} = Request.build(conn)
    assert changeset.errors[:request]
  end

  test "request can be built from URL alone" do
    payload = %{
      name: "pageview",
      url: "http://dummy.site"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    assert request.domains == ["dummy.site"]
    assert request.event_name == "pageview"
    assert request.pathname == "/"
    assert request.remote_ip == "127.0.0.1"
    assert %NaiveDateTime{} = request.timestamp
    assert request.user_agent == nil
    assert request.hostname == "dummy.site"
    assert request.uri.host == "dummy.site"
    assert request.uri.scheme == "http"
    assert request.props == %{}
  end

  test "requests include moving timestamp" do
    payload = %{
      name: "pageview",
      url: "http://dummy.site"
    }

    conn = build_conn(:post, "/api/events", payload)

    assert {:ok, request1} = Request.build(conn)
    :timer.sleep(1500)
    assert {:ok, request2} = Request.build(conn)

    ts1 = request1.timestamp
    ts2 = request2.timestamp

    assert NaiveDateTime.compare(ts1, ts2) == :lt
  end

  test "request can be built with domain" do
    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "http://dummy.site/index"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)
    assert request.domains == ["dummy.site"]
    assert request.uri.host == "dummy.site"
  end

  test "request can be built with domain using shorthands" do
    payload = %{
      n: "pageview",
      d: "dummy.site",
      u: "http://dummy.site/index"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)
    assert request.domains == ["dummy.site"]
    assert request.uri.host == "dummy.site"
  end

  test "request can be built for multiple domains" do
    payload = %{
      n: "pageview",
      d: "dummy.site,crash.site",
      u: "http://dummy.site/index"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)
    assert request.domains == ["dummy.site", "crash.site"]
    assert request.uri.host == "dummy.site"
  end

  test "hostname is (none) if host-less uri provided" do
    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "about:config"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)
    assert request.hostname == "(none)"
  end

  test "hostname is set" do
    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "http://dummy.site/index.html"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)
    assert request.hostname == "dummy.site"
  end

  test "user agent is set as-is" do
    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "http://dummy.site/index.html"
    }

    conn = build_conn(:post, "/api/events", payload) |> put_req_header("user-agent", "Mozilla")
    assert {:ok, request} = Request.build(conn)
    assert request.user_agent == "Mozilla"
  end

  test "request params are set" do
    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "http://dummy.site/index.html",
      referrer: "https://example.com",
      hashMode: 1,
      props: %{
        "custom1" => "property1",
        "custom2" => "property2"
      }
    }

    conn = build_conn(:post, "/api/events", payload)

    assert {:ok, request} = Request.build(conn)
    assert request.referrer == "https://example.com"
    assert request.hash_mode == 1
    assert request.props["custom1"] == "property1"
    assert request.props["custom2"] == "property2"
  end

  test "pathname is set" do
    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "http://dummy.site/pictures/index.html#foo"
    }

    conn = build_conn(:post, "/api/events", payload)

    assert {:ok, request} = Request.build(conn)

    assert request.pathname == "/pictures/index.html"
  end

  test "pathname is set with hashMode" do
    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "http://dummy.site/pictures/index.html#foo",
      hashMode: 1
    }

    conn = build_conn(:post, "/api/events", payload)

    assert {:ok, request} = Request.build(conn)

    assert request.pathname == "/pictures/index.html#foo"
  end

  test "query params are set" do
    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "http://dummy.site/pictures/index.html?foo=bar&baz=bam"
    }

    conn = build_conn(:post, "/api/events", payload)

    assert {:ok, request} = Request.build(conn)
    assert request.query_params["foo"] == "bar"
    assert request.query_params["baz"] == "bam"
  end

  test "returns validation error when using data uris" do
    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "data:text/html,%3Cscript%3Ealert%28%27hi%27%29%3B%3C%2Fscript%3E"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:error, changeset} = Request.build(conn)
    assert {"scheme is not allowed", _} = changeset.errors[:url]
  end

  test "returns validation error when pathname is too long" do
    long_string = for _ <- 1..5000, do: "a", into: ""

    payload = %{
      name: "pageview",
      domain: "dummy.site",
      url: "https://dummy.site/#{long_string}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:error, changeset} = Request.build(conn)
    assert {"should be at most %{count} character(s)", _} = changeset.errors[:pathname]
  end
end
