defmodule PlausibleWeb.Api.ExternalControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.ClickhouseRepo

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"

  describe "POST /api/event" do
    setup do
      site1 = insert(:site)
      {:ok, domain: site1.domain}
    end

    test "records the event", %{conn: conn, domain: domain} do
      params = %{
        domain: domain,
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "http://m.facebook.com/",
        screen_width: 1440
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.hostname == "gigride.live"
      assert pageview.domain == domain
      assert pageview.pathname == "/"
    end

    test "works with Content-Type: text/plain", %{conn: conn, domain: domain} do
      params = %{
        domain: domain,
        name: "pageview",
        url: "http://gigride.live/",
        screen_width: 1440
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.hostname == "gigride.live"
      assert pageview.domain == domain
      assert pageview.pathname == "/"
    end

    test "returns error if JSON cannot be parsed", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post("/api/event", "")

      assert conn.status == 400
    end

    test "can send to multiple dashboards by listing multiple domains - same timestamp", %{
      conn: conn,
      domain: domain1
    } do
      domain2 = insert(:site).domain

      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "http://m.facebook.com/",
        domain: "#{domain1},#{domain2}",
        screen_width: 1440
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      assert response(conn, 202) == "ok"
      assert e1 = get_event(domain1)
      assert e2 = get_event(domain2)

      assert NaiveDateTime.compare(e1.timestamp, e2.timestamp) == :eq
    end

    test "timestamps differ when two events sent in a row", %{conn: conn, domain: domain} do
      params = %{
        domain: domain,
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "http://m.facebook.com/",
        screen_width: 1440
      }

      t1 = System.convert_time_unit(System.monotonic_time(), :native, :millisecond)

      conn
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", params)

      t2 = System.convert_time_unit(System.monotonic_time(), :native, :millisecond)

      # timestamps are in second precision, so we need to wait for it to flip
      Process.sleep(1000 - (t2 - t1))

      conn
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", params)

      [e1, e2] = get_events(domain)

      assert NaiveDateTime.compare(e1.timestamp, e2.timestamp) == :gt
    end

    test "www. is stripped from domain", %{conn: conn, domain: domain} do
      params = %{
        name: "custom event",
        url: "http://gigride.live/",
        domain: domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.domain == domain
    end

    test "www. is stripped from hostname", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        domain: domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.hostname == "example.com"
    end

    test "empty path defaults to /", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://www.example.com",
        domain: domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.pathname == "/"
    end

    test "trailing whitespace is removed", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/path ",
        domain: domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.pathname == "/path"
    end

    test "bots and crawlers are ignored", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        domain: domain
      }

      conn
      |> put_req_header("user-agent", "generic crawler")
      |> post("/api/event", params)

      assert get_event("external-controller-test-5.com") == nil
    end

    test "Headless Chrome is ignored", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        domain: domain
      }

      conn
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/85.0.4183.83 Safari/537.36"
      )
      |> post("/api/event", params)

      assert get_event(domain) == nil
    end

    test "parses user_agent", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.operating_system == "Mac"
      assert pageview.operating_system_version == "10.13"
      assert pageview.browser == "Chrome"
      assert pageview.browser_version == "70.0"
    end

    test "parses referrer", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://facebook.com",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.referrer_source == "Facebook"
    end

    test "strips trailing slash from referrer", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://facebook.com/page/",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.referrer == "facebook.com/page"
      assert pageview.referrer_source == "Facebook"
    end

    test "ignores event when referrer is a spammer", %{conn: conn, domain: domain} do
      params = %{
        domain: domain,
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://www.1-best-seo.com",
        screen_width: 1440
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      assert response(conn, 202) == "ok"
      assert !get_event(domain)
    end

    test "blocks traffic from a domain when it's blocked", %{
      conn: conn
    } do
      site = insert(:site, ingest_rate_limit_threshold: 0)

      params = %{
        domain: site.domain,
        name: "pageview",
        url: "https://feature-flag-test.com"
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      assert response(conn, 202) == "ok"
      refute get_event(site.domain)
    end

    test "ignores when referrer is internal", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://gigride.live",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.referrer_source == ""
    end

    test "ignores localhost referrer", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "http://localhost:4000/",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.referrer_source == ""
    end

    test "parses subdomain referrer", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://blog.gigride.live",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.referrer_source == "blog.gigride.live"
    end

    test "referrer is cleaned", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        referrer: "https://www.indiehackers.com/page?query=param#hash",
        domain: domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.referrer == "indiehackers.com/page"
    end

    test "utm_source overrides referrer source", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/?utm_source=betalist",
        referrer: "https://betalist.com/my-produxct",
        domain: domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.referrer_source == "betalist"
    end

    test "utm tags are stored", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url:
          "http://www.example.com/?utm_medium=ads&utm_source=instagram&utm_campaign=video_story",
        domain: domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.utm_medium == "ads"
      assert pageview.utm_source == "instagram"
      assert pageview.utm_campaign == "video_story"
    end

    test "if it's an :unknown referrer, just the domain is used", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://www.indiehackers.com/landing-page-feedback",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.referrer_source == "indiehackers.com"
    end

    test "if the referrer is not http or https, it is ignored", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "android-app://com.google.android.gm",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.referrer_source == ""
    end

    test "screen size is calculated from screen_width", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        screen_width: 480,
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.screen_size == "Mobile"
    end

    test "screen size is nil if screen_width is missing", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.screen_size == ""
    end

    test "can trigger a custom event", %{conn: conn, domain: domain} do
      params = %{
        name: "custom event",
        url: "http://gigride.live/",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      event = get_event(domain)

      assert response(conn, 202) == "ok"
      assert event.name == "custom event"
    end

    test "casts custom props to string", %{conn: conn, domain: domain} do
      params = %{
        name: "Signup",
        url: "http://gigride.live/",
        domain: domain,
        props: %{
          bool_test: true,
          number_test: 12
        }
      }

      conn
      |> post("/api/event", params)

      event = get_event(domain)

      assert Map.get(event, :"meta.key") == ["bool_test", "number_test"]
      assert Map.get(event, :"meta.value") == ["true", "12"]
    end

    test "ignores malformed custom props", %{conn: conn, domain: domain} do
      params = %{
        name: "Signup",
        url: "http://gigride.live/",
        domain: domain,
        props: "\"show-more:button\""
      }

      conn
      |> post("/api/event", params)

      event = get_event(domain)

      assert Map.get(event, :"meta.key") == []
      assert Map.get(event, :"meta.value") == []
    end

    test "can send props stringified", %{conn: conn, domain: domain} do
      params = %{
        name: "Signup",
        url: "http://gigride.live/",
        domain: domain,
        props: Jason.encode!(%{number_test: 12})
      }

      conn
      |> post("/api/event", params)

      event = get_event(domain)

      assert Map.get(event, :"meta.key") == ["number_test"]
      assert Map.get(event, :"meta.value") == ["12"]
    end

    test "ignores custom prop with array value", %{conn: conn, domain: domain} do
      params = %{
        name: "Signup",
        url: "http://gigride.live/",
        domain: domain,
        props: Jason.encode!(%{wat: ["some-thing"], other: "key"})
      }

      conn = post(conn, "/api/event", params)

      assert conn.status == 202

      event = get_event(domain)

      assert Map.get(event, :"meta.key") == ["other"]
      assert Map.get(event, :"meta.value") == ["key"]
    end

    test "ignores custom prop with map value", %{conn: conn, domain: domain} do
      params = %{
        name: "Signup",
        url: "http://gigride.live/",
        domain: domain,
        props: Jason.encode!(%{foo: %{bar: "baz"}, other_key: 1})
      }

      conn = post(conn, "/api/event", params)

      assert conn.status == 202

      event = get_event(domain)

      assert Map.get(event, :"meta.key") == ["other_key"]
      assert Map.get(event, :"meta.value") == ["1"]
    end

    test "ignores custom prop with empty string value", %{conn: conn, domain: domain} do
      params = %{
        name: "Signup",
        url: "http://gigride.live/",
        domain: domain,
        props: Jason.encode!(%{foo: "", other_key: true})
      }

      conn = post(conn, "/api/event", params)

      assert conn.status == 202

      event = get_event(domain)

      assert Map.get(event, :"meta.key") == ["other_key"]
      assert Map.get(event, :"meta.value") == ["true"]
    end

    test "ignores custom prop with nil value", %{conn: conn, domain: domain} do
      params = %{
        name: "Signup",
        url: "http://gigride.live/",
        domain: domain,
        props: Jason.encode!(%{foo: nil, other_key: true})
      }

      conn = post(conn, "/api/event", params)

      assert conn.status == 202

      event = get_event(domain)

      assert Map.get(event, :"meta.key") == ["other_key"]
      assert Map.get(event, :"meta.value") == ["true"]
    end

    test "ignores a malformed referrer URL", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https:://twitter.com",
        domain: domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      event = get_event(domain)

      assert response(conn, 202) == "ok"
      assert event.referrer == ""
    end

    # Fake data is set up in config/test.exs
    test "looks up location data from the ip address", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("x-forwarded-for", "2.2.2.2")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == "FR"
      assert pageview.subdivision1_code == "FR-IDF"
      assert pageview.subdivision2_code == "FR-75"
      assert pageview.city_geoname_id == 2_988_507
    end

    test "ignores unknown country code ZZ", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.0")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == <<0, 0>>
      assert pageview.subdivision1_code == ""
      assert pageview.subdivision2_code == ""
      assert pageview.city_geoname_id == 0
    end

    test "ignores disputed territory code XX", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.1")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == <<0, 0>>
      assert pageview.subdivision1_code == ""
      assert pageview.subdivision2_code == ""
      assert pageview.city_geoname_id == 0
    end

    test "ignores TOR exit node country code T1", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.2")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == <<0, 0>>
      assert pageview.subdivision1_code == ""
      assert pageview.subdivision2_code == ""
      assert pageview.city_geoname_id == 0
    end

    test "scrubs port from x-forwarded-for", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("x-forwarded-for", "1.1.1.1:123")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == "US"
    end

    test "works with ipv6 without port in x-forwarded-for", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("x-forwarded-for", "1:1:1:1:1:1:1:1")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == "US"
    end

    test "works with ipv6 with a port number in x-forwarded-for", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("x-forwarded-for", "[1:1:1:1:1:1:1:1]:123")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == "US"
    end

    test "uses cloudflare's special header for client IP address if present", %{
      conn: conn,
      domain: domain
    } do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.0")
      |> put_req_header("cf-connecting-ip", "1.1.1.1")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == "US"
    end

    test "uses BunnyCDN's custom header for client IP address if present", %{
      conn: conn,
      domain: domain
    } do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.0")
      |> put_req_header("b-forwarded-for", "1.1.1.1,9.9.9.9")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == "US"
    end

    test "Uses the Forwarded header when cf-connecting-ip and x-forwarded-for are missing", %{
      conn: conn,
      domain: domain
    } do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header("forwarded", "by=0.0.0.0;for=1.1.1.1;host=somehost.com;proto=https")
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == "US"
    end

    test "Forwarded header can parse ipv6", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        domain: domain,
        url: "http://gigride.live/"
      }

      conn
      |> put_req_header(
        "forwarded",
        "by=0.0.0.0;for=\"[1:1:1:1:1:1:1:1]\",for=0.0.0.0;host=somehost.com;proto=https"
      )
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.country_code == "US"
    end

    test "URL is decoded", %{conn: conn, domain: domain} do
      params = %{
        name: "pageview",
        url:
          "http://www.example.com/opportunity/category/%D8%AC%D9%88%D8%A7%D8%A6%D8%B2-%D9%88%D9%85%D8%B3%D8%A7%D8%A8%D9%82%D8%A7%D8%AA",
        domain: domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.pathname == "/opportunity/category/جوائز-ومسابقات"
    end

    test "accepts shorthand map keys", %{conn: conn, domain: domain} do
      params = %{
        n: "pageview",
        u: "http://www.example.com/opportunity",
        d: domain,
        r: "https://facebook.com/page",
        w: 300
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.pathname == "/opportunity"
      assert pageview.referrer_source == "Facebook"
      assert pageview.referrer == "facebook.com/page"
      assert pageview.screen_size == "Mobile"
    end

    test "records hash when in hash mode", %{conn: conn, domain: domain} do
      params = %{
        n: "pageview",
        u: "http://www.example.com/#page-a",
        d: domain,
        h: 1
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.pathname == "/#page-a"
    end

    test "does not record hash when hash mode is 0", %{conn: conn, domain: domain} do
      params = %{
        n: "pageview",
        u: "http://www.example.com/#page-a",
        d: domain,
        h: 0
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.pathname == "/"
    end

    test "decodes URL pathname, fragment and search", %{conn: conn, domain: domain} do
      params = %{
        n: "pageview",
        u:
          "https://test.com/%EF%BA%9D%EF%BB%AD%EF%BA%8E%EF%BA%8B%EF%BA%AF-%EF%BB%AE%EF%BB%A4%EF%BA%B3%EF%BA%8E%EF%BA%92%EF%BB%97%EF%BA%8E%EF%BA%97?utm_source=%25balle%25",
        d: domain,
        h: 1
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.hostname == "test.com"
      assert pageview.pathname == "/ﺝﻭﺎﺋﺯ-ﻮﻤﺳﺎﺒﻗﺎﺗ"
      assert pageview.utm_source == "%balle%"
    end

    test "can use double quotes in query params", %{conn: conn, domain: domain} do
      q = URI.encode_query(%{"utm_source" => "Something \"quoted\""})

      params = %{
        n: "pageview",
        u: "https://test.com/?" <> q,
        d: domain,
        h: 1
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(domain)

      assert pageview.utm_source == "Something \"quoted\""
    end

    test "responds 400 when required fields are missing", %{conn: conn, domain: domain} do
      params = %{
        domain: domain,
        name: "pageview"
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      assert json_response(conn, 400) == %{
               "errors" => %{
                 "url" => ["is required"]
               }
             }
    end

    test "responds 400 with errors when domain is missing", %{conn: conn} do
      params = %{
        domain: nil,
        url: "about:config",
        name: "pageview"
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      assert json_response(conn, 400) == %{
               "errors" => %{
                 "domain" => ["can't be blank"]
               }
             }
    end
  end

  describe "user_id generation" do
    setup do
      site1 = insert(:site)
      {:ok, domain: site1.domain}
    end

    test "with same IP address and user agent, the same user ID is generated", %{
      conn: conn,
      domain: domain
    } do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: domain,
        name: "pageview"
      }

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      [one, two] = get_events(domain)

      assert one.user_id == two.user_id
    end

    test "different IP address results in different user ID", %{conn: conn, domain: domain} do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: domain,
        name: "pageview"
      }

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "982.32.12.1")
      |> post("/api/event", params)

      [one, two] = get_events(domain)

      assert one.user_id != two.user_id
    end

    test "different user agent results in different user ID", %{conn: conn, domain: domain} do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: domain,
        name: "pageview"
      }

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      conn
      |> put_req_header("user-agent", @user_agent <> "!!")
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      [one, two] = get_events(domain)

      assert one.user_id != two.user_id
    end

    test "different domain value results in different user ID", %{conn: conn, domain: domain1} do
      domain2 = insert(:site).domain

      params = %{
        url: "https://user-id-test-domain.com/",
        domain: domain1,
        name: "pageview"
      }

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", Map.put(params, :domain, domain2))

      one = get_event(domain1)
      two = get_event(domain2)

      assert one.user_id != two.user_id
    end

    test "different hostname results in different user ID", %{conn: conn, domain: domain} do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: domain,
        name: "pageview"
      }

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", Map.put(params, :url, "https://other-domain.com/"))

      [one, two] = get_events(domain)

      assert one.user_id != two.user_id
    end

    test "different hostname results in the same user ID when the root domain in the same", %{
      conn: conn,
      domain: domain
    } do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: domain,
        name: "pageview"
      }

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", Map.put(params, :url, "https://app.user-id-test-domain.com/"))

      [one, two] = get_events(domain)

      assert one.user_id == two.user_id
    end
  end

  describe "remaining" do
    setup do
      site1 = insert(:site)
      {:ok, domain: site1.domain}
    end

    test "defaults hostname to (none) when missing", %{conn: conn, domain: domain} do
      params = %{
        domain: domain,
        name: "pageview",
        url: "file:///android_asset/www/index.html"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.hostname == "(none)"
    end

    test "accepts chrome extension URLs", %{conn: conn, domain: domain} do
      params = %{
        domain: domain,
        name: "pageview",
        url: "chrome-extension://liipgellkffekalgefpjolodblggkmjg/popup.html"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event(domain)

      assert response(conn, 202) == "ok"
      assert pageview.hostname == "liipgellkffekalgefpjolodblggkmjg"
    end
  end

  describe "GET /api/health" do
    test "returns 200 OK", %{conn: conn} do
      conn = get(conn, "/api/health")

      assert payload = json_response(conn, 200)
      assert payload["postgres"] == "ok"
      assert payload["clickhouse"] == "ok"
      assert payload["sites_cache"] == "ok"
    end
  end

  defp get_event(domain) do
    Plausible.Event.WriteBuffer.flush()

    ClickhouseRepo.one(
      from e in Plausible.ClickhouseEvent,
        where: e.domain == ^domain,
        order_by: [desc: e.timestamp]
    )
  end

  defp get_events(domain) do
    Plausible.Event.WriteBuffer.flush()

    ClickhouseRepo.all(
      from e in Plausible.ClickhouseEvent,
        where: e.domain == ^domain,
        order_by: [desc: e.timestamp]
    )
  end
end
