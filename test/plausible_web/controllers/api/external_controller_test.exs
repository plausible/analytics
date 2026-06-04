defmodule PlausibleWeb.Api.ExternalControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.ClickhouseRepo

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"
  @user_agent_mobile "Mozilla/5.0 (Linux; Android 6.0; U007 Pro Build/MRA58K; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/44.0.2403.119 Mobile Safari/537.36"
  @user_agent_tablet "Mozilla/5.0 (Linux; U; Android 4.2.2; it-it; Surfing TAB B 9.7 3G Build/JDQ39) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"

  describe "POST /api/event" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "records the event and session", %{conn: conn, site: site} do
      params = %{
        domain: site.domain,
        name: "pageview",
        url: "http://example.com/",
        referrer: "http://m.facebook.com/"
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(site)
      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert pageview.hostname == "example.com"

      assert pageview.site_id == site.id

      assert pageview.pathname == "/"
      assert pageview.session_id == session.session_id
    end

    test "works with Content-Type: text/plain", %{conn: conn, site: site} do
      params = %{
        domain: site.domain,
        name: "pageview",
        url: "http://example.com/"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event(site)

      assert response(conn, 202) == "ok"
      assert pageview.hostname == "example.com"

      assert pageview.site_id == site.id

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
      site: site1
    } do
      site2 = new_site()

      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "http://m.facebook.com/",
        domain: "#{site1.domain},#{site2.domain}"
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      assert response(conn, 202) == "ok"
      assert e1 = get_event(site1)
      assert e2 = get_event(site2)

      assert NaiveDateTime.compare(e1.timestamp, e2.timestamp) == :eq
    end

    @tag :slow
    test "timestamps differ when two events sent in a row", %{conn: conn, site: site} do
      params = %{
        domain: site.domain,
        name: "pageview",
        url: "http://example.com/",
        referrer: "http://m.facebook.com/"
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

      [e1, e2] = get_events(site)

      assert NaiveDateTime.compare(e1.timestamp, e2.timestamp) == :gt
    end

    test "www. is stripped from domain", %{conn: conn, site: site} do
      params = %{
        name: "custom event",
        url: "http://example.com/",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(site)

      assert pageview.site_id == site.id
    end

    test "www. is stripped from hostname", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(site)

      assert pageview.hostname == "example.com"
    end

    test "empty path defaults to /", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(site)

      assert pageview.pathname == "/"
    end

    test "trailing whitespace is removed", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/path ",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(site)

      assert pageview.pathname == "/path"
    end

    test "bots and crawlers are ignored", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        domain: site.domain
      }

      conn
      |> put_req_header("user-agent", "generic crawler")
      |> post("/api/event", params)

      assert get_event(site) == nil
    end

    test "Headless Chrome is ignored", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        domain: site.domain
      }

      conn
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/85.0.4183.83 Safari/537.36"
      )
      |> post("/api/event", params)

      assert get_event(site) == nil
    end

    test "parses user_agent", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)
      event = get_event(site)

      assert response(conn, 202) == "ok"
      assert session.operating_system == "Mac"
      assert session.operating_system_version == "10.13"
      assert session.browser == "Chrome"
      assert session.browser_version == "70.0"
      assert event.operating_system == "Mac"
      assert event.operating_system_version == "10.13"
      assert event.browser == "Chrome"
      assert event.browser_version == "70.0"
    end

    test "parses referrer source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "https://facebook.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Facebook"
      assert session.click_id_param == ""
    end

    test "strips trailing slash from referrer", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "https://facebook.com/page/",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)
      event = get_event(site)

      assert response(conn, 202) == "ok"
      assert session.referrer == "facebook.com/page"
      assert session.referrer_source == "Facebook"
      assert event.referrer == session.referrer
      assert event.referrer_source == session.referrer_source
    end

    test "ignores event when referrer is a spammer", %{conn: conn, site: site} do
      params = %{
        domain: site.domain,
        name: "pageview",
        url: "http://example.com/",
        referrer: "https://www.1-best-seo.com"
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      assert response(conn, 202) == "ok"
      assert !get_event(site)
    end

    test "blocks traffic from a domain when it's blocked", %{
      conn: conn
    } do
      site = new_site(ingest_rate_limit_threshold: 0)

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
      refute get_event(site)
    end

    test "ignores when referrer is internal", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "https://example.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == ""
      assert session.referrer == ""
    end

    test "ignores localhost referrer", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "http://localhost:4000/",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == ""
    end

    test "parses subdomain referrer", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "https://blog.example.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "blog.example.com"
    end

    test "referrer is cleaned", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        referrer: "https://www.indiehackers.com/page?query=param#hash",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.referrer == "indiehackers.com/page"
    end

    test "utm_source overrides referrer source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/?utm_source=betalist",
        referrer: "https://betalist.com/my-produxct",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.referrer_source == "betalist"
      assert session.utm_source == "betalist"
    end

    test "?ref param behaves like ?utm_source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/?ref=betalist",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.referrer_source == "betalist"
      assert session.utm_source == "betalist"
    end

    test "?source param behaves like ?utm_source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/?source=betalist",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.referrer_source == "betalist"
      assert session.utm_source == "betalist"
    end

    test "if utm_source matches a capitalized form from ref_inspector, the capitalized form is recorded",
         %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/?utm_source=facebook",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.referrer_source == "Facebook"
    end

    test "utm tags are stored", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url:
          "http://www.example.com/?utm_medium=ads&utm_source=instagram&utm_campaign=video_story",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.utm_medium == "ads"
      assert session.utm_source == "instagram"
      assert session.utm_campaign == "video_story"
    end

    test "if it's an :unknown referrer, just the domain is used", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "https://www.indiehackers.com/landing-page-feedback",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "indiehackers.com"
    end

    test "if the referrer is not http, https, or android it is ignored", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "ftp://wat",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      pageview = get_event(site)

      assert response(conn, 202) == "ok"
      assert pageview.referrer_source == ""
      assert pageview.referrer == ""
    end

    test "stores referrer from android app", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "android-app://some.android.app",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.referrer == "android-app://some.android.app"
      assert session.referrer_source == "android-app://some.android.app"
    end

    test "screen size is calculated from user agent", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent_mobile)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.screen_size == "Mobile"
    end

    test "screen size is nil if user agent is unknown", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", "unknown UA")
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.screen_size == ""
    end

    test "screen size is calculated from user_agent when is tablet", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent_tablet)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.screen_size == "Tablet"
    end

    test "screen size is calculated from user_agent when is desktop", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.screen_size == "Desktop"
    end

    test "can trigger a custom event", %{conn: conn, site: site} do
      params = %{
        name: "custom event",
        url: "http://example.com/",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      event = get_event(site)

      assert response(conn, 202) == "ok"
      assert event.name == "custom event"
    end

    test "casts custom props to string", %{conn: conn, site: site} do
      params = %{
        name: "Signup",
        url: "http://example.com/",
        domain: site.domain,
        props: %{
          bool_test: true,
          number_test: 12
        }
      }

      conn
      |> post("/api/event", params)

      event = get_event(site)

      assert Map.get(event, :"meta.key") == ["bool_test", "number_test"]
      assert Map.get(event, :"meta.value") == ["true", "12"]
    end

    test "records custom props for a engagement event", %{conn: conn, site: site} do
      post(conn, "/api/event", %{
        n: "pageview",
        u: "https://ab.cd",
        d: site.domain
      })

      post(conn, "/api/event", %{
        name: "engagement",
        url: "http://ab.cd/",
        domain: site.domain,
        sd: 50,
        e: 1000,
        props: %{
          bool_test: true,
          number_test: 12
        }
      })

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert Map.get(engagement, :"meta.key") == ["bool_test", "number_test"]
      assert Map.get(engagement, :"meta.value") == ["true", "12"]
    end

    test "filters out bad props", %{conn: conn, site: site} do
      params = %{
        name: "Signup",
        url: "http://example.com/",
        domain: site.domain,
        props: %{
          false: nil,
          nil: false,
          good: true,
          "      ": "    ",
          "    ": "value",
          key: "    "
        }
      }

      conn
      |> post("/api/event", params)

      event = get_event(site)

      assert Map.get(event, :"meta.key") == ["good"]
      assert Map.get(event, :"meta.value") == ["true"]
    end

    test "ignores malformed custom props", %{conn: conn, site: site} do
      params = %{
        name: "Signup",
        url: "http://example.com/",
        domain: site.domain,
        props: "\"show-more:button\""
      }

      conn
      |> post("/api/event", params)

      event = get_event(site)

      assert Map.get(event, :"meta.key") == []
      assert Map.get(event, :"meta.value") == []
    end

    test "can send props stringified", %{conn: conn, site: site} do
      params = %{
        name: "Signup",
        url: "http://example.com/",
        domain: site.domain,
        props: Jason.encode!(%{number_test: 12})
      }

      conn
      |> post("/api/event", params)

      event = get_event(site)

      assert Map.get(event, :"meta.key") == ["number_test"]
      assert Map.get(event, :"meta.value") == ["12"]
    end

    test "ignores custom prop with array value", %{conn: conn, site: site} do
      params = %{
        name: "Signup",
        url: "http://example.com/",
        domain: site.domain,
        props: Jason.encode!(%{wat: ["some-thing"], other: "key"})
      }

      conn = post(conn, "/api/event", params)

      assert conn.status == 202

      event = get_event(site)

      assert Map.get(event, :"meta.key") == ["other"]
      assert Map.get(event, :"meta.value") == ["key"]
    end

    test "ignores custom prop with map value", %{conn: conn, site: site} do
      params = %{
        name: "Signup",
        url: "http://example.com/",
        domain: site.domain,
        props: Jason.encode!(%{foo: %{bar: "baz"}, other_key: 1})
      }

      conn = post(conn, "/api/event", params)

      assert conn.status == 202

      event = get_event(site)

      assert Map.get(event, :"meta.key") == ["other_key"]
      assert Map.get(event, :"meta.value") == ["1"]
    end

    test "ignores custom prop with empty string value", %{conn: conn, site: site} do
      params = %{
        name: "Signup",
        url: "http://example.com/",
        domain: site.domain,
        props: Jason.encode!(%{foo: "", other_key: true})
      }

      conn = post(conn, "/api/event", params)

      assert conn.status == 202

      event = get_event(site)

      assert Map.get(event, :"meta.key") == ["other_key"]
      assert Map.get(event, :"meta.value") == ["true"]
    end

    test "ignores custom prop with nil value", %{conn: conn, site: site} do
      params = %{
        name: "Signup",
        url: "http://example.com/",
        domain: site.domain,
        props: Jason.encode!(%{foo: nil, other_key: true})
      }

      conn = post(conn, "/api/event", params)

      assert conn.status == 202

      event = get_event(site)

      assert Map.get(event, :"meta.key") == ["other_key"]
      assert Map.get(event, :"meta.value") == ["true"]
    end

    @tag :ee_only
    test "converts revenue values into the goal currency", %{conn: conn, site: site} do
      params = %{
        name: "Payment",
        url: "http://example.com/",
        domain: site.domain,
        revenue: %{amount: 10.2, currency: "USD"}
      }

      insert(:goal, event_name: "Payment", currency: "BRL", site: site)

      assert %{status: 202} = post(conn, "/api/event", params)
      assert %{revenue_reporting_amount: amount} = get_event(site)

      assert Decimal.equal?(Decimal.new("7.14"), amount)
    end

    @tag :ee_only
    test "revenue values can be sent with minified keys", %{conn: conn, site: site} do
      params = %{
        "n" => "Payment",
        "u" => "http://example.com/",
        "d" => site.domain,
        "$" => Jason.encode!(%{amount: 10.2, currency: "USD"})
      }

      insert(:goal, event_name: "Payment", currency: "BRL", site: site)

      assert %{status: 202} = post(conn, "/api/event", params)
      assert %{revenue_reporting_amount: amount} = get_event(site)

      assert Decimal.equal?(Decimal.new("7.14"), amount)
    end

    @tag :ee_only
    test "saves the exact same amount when goal currency is the same as the event", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "Payment",
        url: "http://example.com/",
        domain: site.domain,
        revenue: %{amount: 10, currency: "BRL"}
      }

      insert(:goal, event_name: "Payment", currency: "BRL", site: site)

      assert %{status: 202} = post(conn, "/api/event", params)
      assert %{revenue_reporting_amount: amount} = get_event(site)

      assert Decimal.equal?(Decimal.new("10.0"), amount)
    end

    test "does not fail when revenue value is invalid", %{conn: conn, site: site} do
      params = %{
        name: "Payment",
        url: "http://example.com/",
        domain: site.domain,
        revenue: %{amount: "1831d", currency: "ADSIE"}
      }

      insert(:goal, event_name: "Payment", currency: "BRL", site: site)

      assert %{status: 202} = post(conn, "/api/event", params)
      assert %Plausible.ClickhouseEventV2{} = get_event(site)
    end

    test "does not fail when sending revenue without a matching goal", %{conn: conn, site: site} do
      params = %{
        name: "Add to Cart",
        url: "http://example.com/",
        domain: site.domain,
        revenue: %{amount: 10.2, currency: "USD"}
      }

      insert(:goal, event_name: "Checkout", currency: "BRL", site: site)
      insert(:goal, event_name: "Payment", currency: "USD", site: site)

      assert %{status: 202} = post(conn, "/api/event", params)
      assert %Plausible.ClickhouseEventV2{revenue_reporting_amount: nil} = get_event(site)
    end

    test "ignores a malformed referrer URL", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/",
        referrer: "https:://twitter.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.referrer == ""
    end

    # Fake geo is loaded from test/priv/GeoLite2-City-Test.mmdb
    test "looks up location data from the ip address", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("x-forwarded-for", "2.125.160.216")
      |> post("/api/event", params)

      [session] = get_sessions(site)
      event = get_event(site)

      assert session.country_code == "GB"
      assert session.subdivision1_code == "GB-ENG"
      assert session.subdivision2_code == "GB-WBK"
      assert session.city_geoname_id == 2_655_045
      assert event.country_code == session.country_code
      assert event.subdivision1_code == session.subdivision1_code
      assert event.subdivision2_code == session.subdivision2_code
      assert event.city_geoname_id == session.city_geoname_id
    end

    test "ignores unknown country code ZZ", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.0")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == <<0, 0>>
      assert session.subdivision1_code == ""
      assert session.subdivision2_code == ""
      assert session.city_geoname_id == 0
    end

    test "ignores disputed territory code XX", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.1")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == <<0, 0>>
      assert session.subdivision1_code == ""
      assert session.subdivision2_code == ""
      assert session.city_geoname_id == 0
    end

    test "ignores TOR exit node country code T1", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.2")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == <<0, 0>>
      assert session.subdivision1_code == ""
      assert session.subdivision2_code == ""
      assert session.city_geoname_id == 0
    end

    test "scrubs port from x-forwarded-for", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("x-forwarded-for", "216.160.83.56:123")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == "US"
    end

    test "works with ipv6 without port in x-forwarded-for", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("x-forwarded-for", "2001:218:1:1:1:1:1:1")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == "JP"
    end

    test "works with ipv6 with a port number in x-forwarded-for", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("x-forwarded-for", "[2001:218:1:1:1:1:1:1]:123")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == "JP"
    end

    test "uses cloudflare's special header for client IP address if present", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.0")
      |> put_req_header("cf-connecting-ip", "216.160.83.56")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == "US"
    end

    test "uses BunnyCDN's custom header for client IP address if present", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("x-forwarded-for", "0.0.0.0")
      |> put_req_header("b-forwarded-for", "216.160.83.56,9.9.9.9")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == "US"
    end

    test "prioritizes x-plausible-ip header over everything else", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      conn
      |> put_req_header("cf-connecting-ip", "0.0.0.0")
      |> put_req_header("b-forwarded-for", "0.0.0.0")
      |> put_req_header("x-forwarded-for", "0.0.0.0")
      |> put_req_header("forwarded", "for=0.0.0.0;host=dashboard.site.com;proto=https")
      |> put_req_header("x-plausible-ip", "216.160.83.56")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == "US"
    end

    test "Uses the Forwarded header when cf-connecting-ip and x-forwarded-for are missing", %{
      site: site
    } do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      build_conn()
      |> put_req_header("forwarded", "by=0.0.0.0;for=216.160.83.56;host=somehost.com;proto=https")
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == "US"
    end

    test "Forwarded header can parse ipv6", %{site: site} do
      params = %{
        name: "pageview",
        domain: site.domain,
        url: "http://example.com/"
      }

      build_conn()
      |> put_req_header(
        "forwarded",
        "by=0.0.0.0;for=\"[2001:218:1:1:1:1:1:1]\",for=0.0.0.0;host=somehost.com;proto=https"
      )
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.country_code == "JP"
    end

    test "URL is decoded", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url:
          "http://www.example.com/opportunity/category/%D8%AC%D9%88%D8%A7%D8%A6%D8%B2-%D9%88%D9%85%D8%B3%D8%A7%D8%A8%D9%82%D8%A7%D8%AA",
        domain: site.domain
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(site)

      assert pageview.pathname == "/opportunity/category/جوائز-ومسابقات"
    end

    test "accepts shorthand map keys", %{conn: conn, site: site} do
      params = %{
        n: "pageview",
        u: "http://www.example.com/opportunity",
        d: site.domain,
        r: "https://facebook.com/page"
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(site)
      [session] = get_sessions(site)

      assert pageview.pathname == "/opportunity"
      assert session.referrer_source == "Facebook"
      assert session.referrer == "facebook.com/page"
    end

    test "records hash when in hash mode", %{conn: conn, site: site} do
      params = %{
        n: "pageview",
        u: "http://www.example.com/#page-a",
        d: site.domain,
        h: 1
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(site)

      assert pageview.pathname == "/#page-a"
    end

    test "does not record hash when hash mode is 0", %{conn: conn, site: site} do
      params = %{
        n: "pageview",
        u: "http://www.example.com/#page-a",
        d: site.domain,
        h: 0
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(site)

      assert pageview.pathname == "/"
    end

    test "decodes URL pathname, fragment and search", %{conn: conn, site: site} do
      params = %{
        n: "pageview",
        u:
          "https://test.com/%EF%BA%9D%EF%BB%AD%EF%BA%8E%EF%BA%8B%EF%BA%AF-%EF%BB%AE%EF%BB%A4%EF%BA%B3%EF%BA%8E%EF%BA%92%EF%BB%97%EF%BA%8E%EF%BA%97?utm_source=%25balle%25",
        d: site.domain,
        h: 1
      }

      conn
      |> post("/api/event", params)

      pageview = get_event(site)
      [session] = get_sessions(site)

      assert pageview.hostname == "test.com"
      assert pageview.pathname == "/ﺝﻭﺎﺋﺯ-ﻮﻤﺳﺎﺒﻗﺎﺗ"
      assert session.utm_source == "%balle%"
      assert pageview.utm_source == session.utm_source
    end

    test "can use double quotes in query params", %{conn: conn, site: site} do
      q = URI.encode_query(%{"utm_source" => "Something \"quoted\""})

      params = %{
        n: "pageview",
        u: "https://test.com/?" <> q,
        d: site.domain,
        h: 1
      }

      conn
      |> post("/api/event", params)

      [session] = get_sessions(site)

      assert session.utm_source == "Something \"quoted\""
    end

    test "responds 400 when required fields are missing", %{conn: conn, site: site} do
      params = %{
        domain: site.domain,
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

    test "responds 400 when event name is blank", %{conn: conn, site: site} do
      params = %{
        domain: site.domain,
        name: "",
        url: "http://example.com"
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      assert json_response(conn, 400) == %{
               "errors" => %{
                 "event_name" => ["can't be blank"]
               }
             }
    end

    test "salts rotating once does not", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      Plausible.Session.WriteBuffer.flush()
      Plausible.Session.Salts.rotate()

      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})

      [event1, event2] = get_events(site)
      [session1, session2] = get_sessions(site)

      records = [event1, event2, session1, session2]

      assert records |> Enum.map(& &1.user_id) |> Enum.uniq() |> Enum.count() == 1
      assert records |> Enum.map(& &1.session_id) |> Enum.uniq() |> Enum.count() == 1
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

  describe "engagement event tests" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "rejects engagement when both sd and e fields are missing", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})

      conn = post(conn, "/api/event", %{n: "engagement", u: "https://test.com", d: site.domain})

      assert %{"errors" => %{"event_name" => [error_msg]}} = json_response(conn, 400)

      assert error_msg =~
               "engagement event requires a valid integer value for at least one of 'sd' or 'e' fields"
    end

    test "ingests scroll_depth as 255 when not in params", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "engagement", u: "https://test.com", d: site.domain, e: 200})

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.scroll_depth == 255
    end

    test "ingests engagement_time as 0 when not in params", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "engagement", u: "https://test.com", d: site.domain, sd: 50})

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.engagement_time == 0
    end

    test "ingests engagement_time as 0 when tracker is sending invalid high values", %{
      conn: conn,
      site: site
    } do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})

      post(conn, "/api/event", %{
        n: "engagement",
        u: "https://test.com",
        d: site.domain,
        sd: 50,
        e: 1_741_850_224_785
      })

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.engagement_time == 0
      assert engagement.scroll_depth == 50
    end

    test "sd and e fields are ignored if name is not engagement", %{conn: conn, site: site} do
      post(conn, "/api/event", %{
        n: "pageview",
        u: "https://test.com",
        d: site.domain,
        sd: 10,
        e: 789
      })

      post(conn, "/api/event", %{
        n: "custom_e",
        u: "https://test.com",
        d: site.domain,
        sd: 10,
        e: 789
      })

      assert [%{scroll_depth: 0, engagement_time: 0}, %{scroll_depth: 0, engagement_time: 0}] =
               get_events(site)
    end

    test "ingests valid scroll_depth and engagement_time for a engagement", %{
      conn: conn,
      site: site
    } do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})

      post(conn, "/api/event", %{
        n: "engagement",
        u: "https://test.com",
        d: site.domain,
        sd: 25,
        e: 789
      })

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.scroll_depth == 25
      assert engagement.engagement_time == 789
    end

    test "ingests scroll_depth as 100 when sd > 100", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "engagement", u: "https://test.com", d: site.domain, sd: 101})

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.scroll_depth == 100
    end

    test "parses scroll_depth from a string", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "engagement", u: "https://test.com", d: site.domain, sd: "1"})

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.scroll_depth == 1
    end

    test "ingests scroll_depth as 255 when sd is a negative integer", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})

      post(conn, "/api/event", %{
        n: "engagement",
        u: "https://test.com",
        d: site.domain,
        sd: -1,
        e: 100
      })

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.scroll_depth == 255
    end

    test "ingests scroll_depth as 255 when sd is a non-number string", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})

      post(conn, "/api/event", %{
        n: "engagement",
        u: "https://test.com",
        d: site.domain,
        sd: "12asd",
        e: 100
      })

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.scroll_depth == 255
    end

    test "ingests engagement_time from a string", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})

      post(conn, "/api/event", %{
        n: "engagement",
        u: "https://test.com",
        d: site.domain,
        e: "789",
        sd: 40
      })

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.engagement_time == 789
    end

    test "ingests engagement_time as 0 when e is a negative integer", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})

      post(conn, "/api/event", %{
        n: "engagement",
        u: "https://test.com",
        d: site.domain,
        e: -100,
        sd: 50
      })

      engagement = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert engagement.engagement_time == 0
    end
  end

  describe "acquisition channel tests" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "parses cross network channel", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com/?utm_campaign=cross-network"})
      |> assert_acquisition_channel("Cross-network")
    end

    test "parses paid shopping channel based on campaign/medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com/?utm_campaign=shopping&utm_medium=paid"})
      |> assert_acquisition_channel("Paid Shopping")
    end

    test "parses paid shopping channel based on referrer source and medium", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?utm_medium=paid",
        referrer: "https://shopify.com"
      })
      |> assert_acquisition_channel("Paid Shopping")
    end

    test "parses paid shopping channel based on referrer utm_source and medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=shopify&utm_medium=paid"})
      |> assert_acquisition_channel("Paid Shopping")
    end

    test "parses paid search channel based on referrer and medium", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?utm_medium=paid",
        referrer: "https://duckduckgo.com"
      })
      |> assert_acquisition_channel("Paid Search")
    end

    test "parses paid search channel based on gclid", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?gclid=123identifier",
        referrer: "https://google.com"
      })
      |> assert_acquisition_channel("Paid Search")
      |> assert_utm_medium("(gclid)")
      |> assert_click_id_param("gclid")
    end

    test "is not paid search when gclid is present on non-google referrer", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?gclid=123identifier",
        referrer: "https://duckduckgo.com"
      })
      |> assert_acquisition_channel("Organic Search")
      |> assert_utm_medium("")
      |> assert_click_id_param("gclid")
    end

    test "does not override utm_medium with (gclid) if link is already tagged", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?gclid=123identifier&utm_medium=paidads",
        referrer: "https://google.com"
      })
      |> assert_acquisition_channel("Paid Search")
      |> assert_utm_medium("paidads")
      |> assert_click_id_param("gclid")
    end

    test "parses paid search channel based on msclkid", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?msclkid=123identifier",
        referrer: "https://bing.com"
      })
      |> assert_acquisition_channel("Paid Search")
      |> assert_utm_medium("(msclkid)")
      |> assert_click_id_param("msclkid")
    end

    test "is not paid search when msclkid is present on non-bing referrer", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?msclkid=123identifier&utm_medium=cpc",
        referrer: "https://bing.com"
      })
      |> assert_acquisition_channel("Paid Search")
      |> assert_utm_medium("cpc")
      |> assert_click_id_param("msclkid")
    end

    test "does not override utm_medium with (msclkid) if link is already tagged", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?gclid=123identifier&utm_medium=paidads",
        referrer: "https://google.com"
      })
      |> assert_acquisition_channel("Paid Search")
      |> assert_utm_medium("paidads")
      |> assert_click_id_param("gclid")
    end

    test "parses paid search channel based on utm_source and medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=google&utm_medium=paid"})
      |> assert_acquisition_channel("Paid Search")
      |> assert_click_id_param("")
    end

    test "parses paid social channel based on referrer and medium", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?utm_medium=paid",
        referrer: "https://tiktok.com"
      })
      |> assert_acquisition_channel("Paid Social")
    end

    test "parses paid social channel based on utm_source and medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=tiktok&utm_medium=paid"})
      |> assert_acquisition_channel("Paid Social")
    end

    test "parses paid video channel based on referrer and medium", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?utm_medium=paid",
        referrer: "https://youtube.com"
      })
      |> assert_acquisition_channel("Paid Video")
    end

    test "parses paid video channel based on utm_source and medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=youtube&utm_medium=paid"})
      |> assert_acquisition_channel("Paid Video")
    end

    test "parses display channel", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=banner"})
      |> assert_acquisition_channel("Display")
    end

    test "display channel with gclid", %{site: site} do
      site
      |> submit_event(%{
        url: "http://example.com?utm_medium=display&utm_source=google&gclid=123identifier"
      })
      |> assert_acquisition_channel("Display")
    end

    test "parses paid other channel", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=cpc"})
      |> assert_acquisition_channel("Paid Other")
    end

    test "parses organic shopping channel from referrer", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com", referrer: "https://walmart.com"})
      |> assert_acquisition_channel("Organic Shopping")
    end

    test "parses organic shopping channel from utm_source", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=walmart"})
      |> assert_acquisition_channel("Organic Shopping")
    end

    test "parses organic shopping channel from utm_campaign", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_campaign=shop"})
      |> assert_acquisition_channel("Organic Shopping")
    end

    test "parses organic social channel from referrer", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com", referrer: "http://facebook.com"})
      |> assert_acquisition_channel("Organic Social")
    end

    test "parses organic social channel from utm_source", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=twitter"})
      |> assert_acquisition_channel("Organic Social")
    end

    test "parses organic social channel from utm_medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=social"})
      |> assert_acquisition_channel("Organic Social")
    end

    test "parses organic video channel from referrer", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com", referrer: "https://vimeo.com"})
      |> assert_acquisition_channel("Organic Video")
    end

    test "parses organic video channel from utm_source", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=vimeo"})
      |> assert_acquisition_channel("Organic Video")
    end

    test "parses organic video channel from utm_medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=video"})
      |> assert_acquisition_channel("Organic Video")
    end

    test "parses organic search channel from referrer", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com", referrer: "http://duckduckgo.com"})
      |> assert_acquisition_channel("Organic Search")
    end

    test "parses organic search channel from utm_source", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=duckduckgo"})
      |> assert_acquisition_channel("Organic Search")
    end

    test "parses referral channel from utm_medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=referral"})
      |> assert_acquisition_channel("Referral")
    end

    test "parses email channel from utm_source", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=email"})
      |> assert_acquisition_channel("Email")
    end

    test "parses email channel from utm_medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=email"})
      |> assert_acquisition_channel("Email")
    end

    test "parses affiliates channel from utm_medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=affiliate"})
      |> assert_acquisition_channel("Affiliates")
    end

    test "parses audio channel from utm_medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=audio"})
      |> assert_acquisition_channel("Audio")
    end

    test "parses sms channel from utm_source", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_source=sms"})
      |> assert_acquisition_channel("SMS")
    end

    test "parses sms channel from utm_medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=sms"})
      |> assert_acquisition_channel("SMS")
    end

    test "parses mobile push notifications channel from utm_medium with push", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=app-push"})
      |> assert_acquisition_channel("Mobile Push Notifications")
    end

    test "parses mobile push notifications channel from utm_medium", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com?utm_medium=example-mobile"})
      |> assert_acquisition_channel("Mobile Push Notifications")
    end

    test "parses referral channel if session starts with a simple referral", %{site: site} do
      site
      |> submit_event(%{url: "http://example.com", referrer: "https://othersite.com"})
      |> assert_acquisition_channel("Referral")
    end

    test "parses direct channel if session starts without referrer or utm tags", %{
      site: site
    } do
      site
      |> submit_event(%{
        name: "pageview",
        url: "http://example.com",
        domain: site.domain
      })
      |> assert_acquisition_channel("Direct")
    end
  end

  describe "custom source parsing rules" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    defp submit_event(site, params_overrides) do
      params =
        Map.merge(
          %{name: "pageview", url: "http://example.com", domain: site.domain},
          params_overrides
        )

      conn =
        build_conn()
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      assert response(conn, 202) == "ok"

      [session] = get_sessions(site)
      session
    end

    defp event_with_referrer(site, referrer) do
      submit_event(site, %{referrer: referrer})
    end

    defp event_with_utm_source(site, utm_source) do
      submit_event(site, %{url: "http://example.com?utm_source=#{utm_source}"})
    end

    defp assert_source(session, expected) do
      assert session.referrer_source == expected
      session
    end

    defp assert_utm_source(session, expected) do
      assert session.utm_source == expected
      session
    end

    defp assert_utm_medium(session, expected) do
      assert session.utm_medium == expected
      session
    end

    defp assert_click_id_param(session, expected) do
      assert session.click_id_param == expected
      session
    end

    defp assert_acquisition_channel(session, expected) do
      assert session.acquisition_channel == expected
      session
    end

    test "threads is Threads", %{site: site} do
      site
      |> event_with_utm_source("threads")
      |> assert_source("Threads")
      |> assert_utm_source("threads")
      |> assert_acquisition_channel("Organic Social")
    end

    test "ig is Instagram", %{site: site} do
      site
      |> event_with_utm_source("ig")
      |> assert_source("Instagram")
      |> assert_utm_source("ig")
      |> assert_acquisition_channel("Organic Social")
    end

    test "yt is Youtube", %{site: site} do
      site
      |> event_with_utm_source("yt")
      |> assert_source("Youtube")
      |> assert_utm_source("yt")
      |> assert_acquisition_channel("Organic Video")
    end

    test "yt-ads is Youtube paid", %{site: site} do
      site
      |> event_with_utm_source("yt-ads")
      |> assert_source("Youtube")
      |> assert_utm_source("yt-ads")
      |> assert_acquisition_channel("Paid Video")
    end

    test "fb is Facebook", %{site: site} do
      site
      |> event_with_utm_source("fb")
      |> assert_source("Facebook")
      |> assert_utm_source("fb")
      |> assert_acquisition_channel("Organic Social")
    end

    test "fb-ads is Facebook", %{site: site} do
      site
      |> event_with_utm_source("fb-ads")
      |> assert_source("Facebook")
      |> assert_utm_source("fb-ads")
      |> assert_acquisition_channel("Paid Social")
    end

    test "fbad is Facebook", %{site: site} do
      site
      |> event_with_utm_source("fbad")
      |> assert_source("Facebook")
      |> assert_utm_source("fbad")
      |> assert_acquisition_channel("Paid Social")
    end

    test "facebook-ads is Facebook", %{site: site} do
      site
      |> event_with_utm_source("facebook-ads")
      |> assert_source("Facebook")
      |> assert_utm_source("facebook-ads")
      |> assert_acquisition_channel("Paid Social")
    end

    test "Reddit-ads is Reddit", %{site: site} do
      site
      |> event_with_utm_source("Reddit-ads")
      |> assert_source("Reddit")
      |> assert_utm_source("Reddit-ads")
      |> assert_acquisition_channel("Paid Social")
    end

    test "google_ads is Google", %{site: site} do
      site
      |> event_with_utm_source("google_ads")
      |> assert_source("Google")
      |> assert_utm_source("google_ads")
      |> assert_acquisition_channel("Paid Search")
    end

    test "Google-ads is Google", %{
      site: site
    } do
      site
      |> submit_event(%{url: "http://example.com?source=Google-ads"})
      |> assert_source("Google")
      |> assert_utm_source("Google-ads")
      |> assert_acquisition_channel("Paid Search")
    end

    test "utm_source=Adwords is Google paid search", %{site: site} do
      site
      |> event_with_utm_source("Adwords")
      |> assert_source("Google")
      |> assert_utm_source("Adwords")
      |> assert_acquisition_channel("Paid Search")
    end

    test "twitter-ads is X (Twitter)", %{site: site} do
      site
      |> event_with_utm_source("twitter-ads")
      |> assert_source("X (Twitter)")
      |> assert_utm_source("twitter-ads")
      |> assert_acquisition_channel("Paid Social")
    end

    test "android-app://com.reddit.frontpage is Reddit", %{site: site} do
      site
      |> event_with_referrer("android-app://com.reddit.frontpage")
      |> assert_source("Reddit")
      |> assert_acquisition_channel("Organic Social")
    end

    test "perplexity.ai is Perplexity", %{site: site} do
      site
      |> event_with_referrer("https://perplexity.ai")
      |> assert_source("Perplexity")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "pplx.ai is Perplexity", %{site: site} do
      site
      |> event_with_referrer("https://pplx.ai")
      |> assert_source("Perplexity")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "utm_source=perplexity is Perplexity", %{site: site} do
      site
      |> event_with_utm_source("perplexity")
      |> assert_source("Perplexity")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "statics.teams.cdn.office.net is Microsoft Teams", %{site: site} do
      site
      |> event_with_referrer("https://statics.teams.cdn.office.net")
      |> assert_source("Microsoft Teams")
      |> assert_acquisition_channel("Organic Social")
    end

    test "wikipedia domain is resolved as Wikipedia", %{site: site} do
      site
      |> event_with_referrer("https://en.wikipedia.org")
      |> assert_source("Wikipedia")
      |> assert_acquisition_channel("Referral")
    end

    test "ntp.msn.com is Bing", %{site: site} do
      site
      |> event_with_referrer("https://ntp.msn.com")
      |> assert_source("Bing")
      |> assert_acquisition_channel("Organic Search")
    end

    test "search.brave.com is Brave", %{site: site} do
      site
      |> event_with_referrer("https://search.brave.com")
      |> assert_source("Brave")
      |> assert_acquisition_channel("Organic Search")
    end

    test "yandex.com.tr is Yandex", %{site: site} do
      site
      |> event_with_referrer("https://yandex.com.tr")
      |> assert_source("Yandex")
      |> assert_acquisition_channel("Organic Search")
    end

    test "yandex.kz is Yandex", %{site: site} do
      site
      |> event_with_referrer("https://yandex.kz")
      |> assert_source("Yandex")
      |> assert_acquisition_channel("Organic Search")
    end

    test "ya.ru is Yandex", %{site: site} do
      site
      |> event_with_referrer("https://ya.ru")
      |> assert_source("Yandex")
      |> assert_acquisition_channel("Organic Search")
    end

    test "yandex.uz is Yandex", %{site: site} do
      site
      |> event_with_referrer("https://yandex.uz")
      |> assert_source("Yandex")
      |> assert_acquisition_channel("Organic Search")
    end

    test "yandex.fr is Yandex", %{site: site} do
      site
      |> event_with_referrer("https://yandex.fr")
      |> assert_source("Yandex")
      |> assert_acquisition_channel("Organic Search")
    end

    test "yandex.eu is Yandex", %{site: site} do
      site
      |> event_with_referrer("https://yandex.eu")
      |> assert_source("Yandex")
      |> assert_acquisition_channel("Organic Search")
    end

    test "yandex.tm is Yandex", %{site: site} do
      site
      |> event_with_referrer("https://yandex.tm")
      |> assert_source("Yandex")
      |> assert_acquisition_channel("Organic Search")
    end

    test "discord.com is Discord", %{site: site} do
      site
      |> event_with_referrer("https://discord.com")
      |> assert_source("Discord")
      |> assert_acquisition_channel("Organic Social")
    end

    test "discordapp.com is Discord", %{site: site} do
      site
      |> event_with_referrer("https://discordapp.com")
      |> assert_source("Discord")
      |> assert_acquisition_channel("Organic Social")
    end

    test "canary.discord.com is Discord", %{site: site} do
      site
      |> event_with_referrer("https://canary.discord.com")
      |> assert_source("Discord")
      |> assert_acquisition_channel("Organic Social")
    end

    test "ptb.discord.com is Discord", %{site: site} do
      site
      |> event_with_referrer("https://ptb.discord.com")
      |> assert_source("Discord")
      |> assert_acquisition_channel("Organic Social")
    end

    test "www.baidu.com is Baidu", %{site: site} do
      site
      |> event_with_referrer("https://baidu.com")
      |> assert_source("Baidu")
      |> assert_acquisition_channel("Organic Search")
    end

    test "t.me is Telegram", %{site: site} do
      site
      |> event_with_referrer("https://t.me")
      |> assert_source("Telegram")
      |> assert_acquisition_channel("Organic Social")
    end

    test "webk.telegram.org is Telegram", %{site: site} do
      site
      |> event_with_referrer("https://webk.telegram.org")
      |> assert_source("Telegram")
      |> assert_acquisition_channel("Organic Social")
    end

    test "sogou.com is Sogou", %{site: site} do
      site
      |> event_with_referrer("https://sogou.com")
      |> assert_source("Sogou")
      |> assert_acquisition_channel("Organic Search")
    end

    test "m.sogou.com is Sogou", %{site: site} do
      site
      |> event_with_referrer("https://m.sogou.com")
      |> assert_source("Sogou")
      |> assert_acquisition_channel("Organic Search")
    end

    test "wap.sogou.com is Sogou", %{site: site} do
      site
      |> event_with_referrer("https://wap.sogou.com")
      |> assert_source("Sogou")
      |> assert_acquisition_channel("Organic Search")
    end

    test "linktr.ee is Linktree", %{site: site} do
      site
      |> event_with_referrer("https://linktr.ee")
      |> assert_source("Linktree")
      |> assert_acquisition_channel("Referral")
    end

    test "linktree is Linktree", %{site: site} do
      site
      |> event_with_utm_source("linktree")
      |> assert_source("Linktree")
      |> assert_acquisition_channel("Referral")
    end
  end

  describe "custom channel parsing rules" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "hacker news is social channel", %{site: site} do
      site
      |> event_with_referrer("https://news.ycombinator.com")
      |> assert_source("Hacker News")
      |> assert_acquisition_channel("Organic Social")
    end

    test "yahoo is organic search", %{site: site} do
      site
      |> event_with_referrer("https://search.yahoo.com")
      |> assert_source("Yahoo!")
      |> assert_acquisition_channel("Organic Search")
    end

    test "gmail is email channel", %{site: site} do
      site
      |> event_with_referrer("https://mail.google.com")
      |> assert_source("Gmail")
      |> assert_acquisition_channel("Email")
    end

    test "utm_source=newsletter is email channel", %{site: site} do
      site
      |> event_with_utm_source("Newsletter-UK")
      |> assert_source("Newsletter-UK")
      |> assert_acquisition_channel("Email")
    end

    test "temu.com is shopping channel", %{site: site} do
      site
      |> event_with_referrer("https://temu.com")
      |> assert_source("temu.com")
      |> assert_acquisition_channel("Organic Shopping")
    end

    test "utm_source=Telegram is social channel", %{site: site} do
      site
      |> event_with_utm_source("Telegram")
      |> assert_source("Telegram")
      |> assert_acquisition_channel("Organic Social")
    end

    test "Slack is social channel", %{site: site} do
      site
      |> event_with_referrer("https://app.slack.com")
      |> assert_source("Slack")
      |> assert_acquisition_channel("Organic Social")
    end

    test "producthunt is social", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?ref=producthunt",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      [session] = get_sessions(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "producthunt"
      assert session.acquisition_channel == "Organic Social"
    end

    test "github is social", %{site: site} do
      site
      |> event_with_referrer("https://github.com")
      |> assert_source("GitHub")
      |> assert_acquisition_channel("Organic Social")
    end

    test "steamcommunity.com is social", %{site: site} do
      site
      |> event_with_referrer("https://steamcommunity.com")
      |> assert_source("steamcommunity.com")
      |> assert_acquisition_channel("Organic Social")
    end

    test "Vkontakte is social", %{site: site} do
      site
      |> event_with_referrer("https://vkontakte.ru")
      |> assert_source("Vkontakte")
      |> assert_acquisition_channel("Organic Social")
    end

    test "Threads is social", %{site: site} do
      site
      |> event_with_referrer("https://threads.net")
      |> assert_source("Threads")
      |> assert_acquisition_channel("Organic Social")
    end

    test "Ecosia is search", %{site: site} do
      site
      |> event_with_referrer("https://ecosia.org")
      |> assert_source("Ecosia")
      |> assert_acquisition_channel("Organic Search")
    end

    test "bsky.app is Bluesky and Organic Social", %{site: site} do
      site
      |> event_with_referrer("https://bsky.app")
      |> assert_source("Bluesky")
      |> assert_acquisition_channel("Organic Social")
    end

    test "go.bsky.app is Bluesky and Organic Social", %{site: site} do
      site
      |> event_with_referrer("https://go.bsky.app")
      |> assert_source("Bluesky")
      |> assert_acquisition_channel("Organic Social")
    end

    test "mastodon.social is Mastodon and Organic Social", %{site: site} do
      site
      |> event_with_referrer("https://mastodon.social")
      |> assert_source("Mastodon")
      |> assert_acquisition_channel("Organic Social")
    end

    test "fosstodon.org is Mastodon and Organic Social", %{site: site} do
      site
      |> event_with_referrer("https://fosstodon.org")
      |> assert_source("Mastodon")
      |> assert_acquisition_channel("Organic Social")
    end

    test "gemini.google.com is Google Gemini and AI Assistants", %{site: site} do
      site
      |> event_with_referrer("https://gemini.google.com")
      |> assert_source("Google Gemini")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "chatgpt.com is ChatGPT and AI Assistants", %{site: site} do
      site
      |> event_with_referrer("https://chatgpt.com")
      |> assert_source("ChatGPT")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "chat.openai.com is ChatGPT and AI Assistants", %{site: site} do
      site
      |> event_with_referrer("https://chat.openai.com")
      |> assert_source("ChatGPT")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "claude.ai is Claude and AI Assistants", %{site: site} do
      site
      |> event_with_referrer("https://claude.ai")
      |> assert_source("Claude")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "phind.com is Phind and AI Assistants", %{site: site} do
      site
      |> event_with_referrer("https://phind.com")
      |> assert_source("Phind")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "copilot.microsoft.com is Microsoft Copilot and AI Assistants", %{site: site} do
      site
      |> event_with_referrer("https://copilot.microsoft.com")
      |> assert_source("Microsoft Copilot")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "copilot.com is Microsoft Copilot and AI Assistants", %{site: site} do
      site
      |> event_with_referrer("https://copilot.com")
      |> assert_source("Microsoft Copilot")
      |> assert_acquisition_channel("AI Assistants")
    end

    test "x.com is X (Twitter) and Organic Social", %{site: site} do
      site
      |> event_with_referrer("https://x.com")
      |> assert_source("X (Twitter)")
      |> assert_acquisition_channel("Organic Social")
    end

    test "l.threads.com is Threads and Organic Social", %{site: site} do
      site
      |> event_with_referrer("https://l.threads.com")
      |> assert_source("Threads")
      |> assert_acquisition_channel("Organic Social")
    end

    test "kagi.com is Kagi and Organic Search", %{site: site} do
      site
      |> event_with_referrer("https://kagi.com")
      |> assert_source("Kagi")
      |> assert_acquisition_channel("Organic Search")
    end

    test "officeapps.live.com subdomains are Microsoft 365 and Referral", %{site: site} do
      site
      |> event_with_referrer("https://cac-excel.officeapps.live.com")
      |> assert_source("Microsoft 365")
      |> assert_acquisition_channel("Referral")
    end
  end

  describe "user_id generation" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "with same IP address and user agent, the same user ID is generated", %{
      conn: conn,
      site: site
    } do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: site.domain,
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

      [one, two] = get_events(site)

      assert one.user_id == two.user_id
    end

    test "different IP address results in different user ID", %{conn: conn, site: site} do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: site.domain,
        name: "pageview"
      }

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "82.32.12.1")
      |> post("/api/event", params)

      [one, two] = get_events(site)

      assert one.user_id != two.user_id
    end

    test "different user agent results in different user ID", %{conn: conn, site: site} do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: site.domain,
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

      [one, two] = get_events(site)

      assert one.user_id != two.user_id
    end

    test "different domain value results in different user ID", %{conn: conn, site: site1} do
      site2 = new_site()

      params = %{
        url: "https://user-id-test-domain.com/",
        domain: site1.domain,
        name: "pageview"
      }

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", params)

      conn
      |> put_req_header("user-agent", @user_agent)
      |> put_req_header("x-forwarded-for", "127.0.0.1")
      |> post("/api/event", Map.put(params, :domain, site2.domain))

      one = get_event(site1)
      two = get_event(site2)

      assert one.user_id != two.user_id
    end

    test "different hostname results in different user ID", %{conn: conn, site: site} do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: site.domain,
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

      [one, two] = get_events(site)

      assert one.user_id != two.user_id
    end

    test "different hostname results in the same user ID when the root domain in the same", %{
      conn: conn,
      site: site
    } do
      params = %{
        url: "https://user-id-test-domain.com/",
        domain: site.domain,
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

      [one, two] = get_events(site)

      assert one.user_id == two.user_id
    end
  end

  describe "remaining" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "defaults hostname to (none) when missing", %{conn: conn, site: site} do
      params = %{
        domain: site.domain,
        name: "pageview",
        url: "file:///android_asset/www/index.html"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event(site)

      assert response(conn, 202) == "ok"
      assert pageview.hostname == "(none)"
    end

    test "accepts chrome extension URLs", %{conn: conn, site: site} do
      params = %{
        domain: site.domain,
        name: "pageview",
        url: "chrome-extension://liipgellkffekalgefpjolodblggkmjg/popup.html"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event(site)

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

  defp get_event(site) do
    Plausible.Event.WriteBuffer.flush()

    ClickhouseRepo.one(
      from(e in Plausible.ClickhouseEventV2,
        where: e.site_id == ^site.id,
        order_by: [desc: e.timestamp]
      )
    )
  end

  defp get_sessions(site) do
    Plausible.Session.WriteBuffer.flush()

    ClickhouseRepo.all(
      from(s in Plausible.ClickhouseSessionV2,
        where: s.site_id == ^site.id and s.sign == 1,
        order_by: [desc: s.timestamp]
      )
    )
  end

  defp get_events(site) do
    Plausible.Event.WriteBuffer.flush()

    ClickhouseRepo.all(
      from(e in Plausible.ClickhouseEventV2,
        where: e.site_id == ^site.id,
        order_by: [desc: e.timestamp]
      )
    )
  end
end
