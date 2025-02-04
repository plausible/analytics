defmodule PlausibleWeb.Api.ExternalControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.ClickhouseRepo
  use Plausible.Teams.Test

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
      session = get_created_session(site)

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

      session = get_created_session(site)
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

      session = get_created_session(site)

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

      session = get_created_session(site)
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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

    test "records custom props for a pageleave event", %{conn: conn, site: site} do
      post(conn, "/api/event", %{
        n: "pageview",
        u: "https://ab.cd",
        d: site.domain
      })

      post(conn, "/api/event", %{
        name: "pageleave",
        url: "http://ab.cd/",
        domain: site.domain,
        props: %{
          bool_test: true,
          number_test: 12
        }
      })

      pageleave = get_events(site) |> Enum.find(&(&1.name == "pageleave"))

      assert Map.get(pageleave, :"meta.key") == ["bool_test", "number_test"]
      assert Map.get(pageleave, :"meta.value") == ["true", "12"]
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

      session = get_created_session(site)

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

      session = get_created_session(site)
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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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

      session = get_created_session(site)

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
      session = get_created_session(site)

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
      session = get_created_session(site)

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

      session = get_created_session(site)

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

  describe "scroll depth tests" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "ingests scroll_depth as 255 when sd not in params", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "pageleave", u: "https://test.com", d: site.domain})

      pageleave = get_events(site) |> Enum.find(&(&1.name == "pageleave"))

      assert pageleave.scroll_depth == 255
    end

    test "sd field is ignored if name is not pageleave", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain, sd: 10})
      post(conn, "/api/event", %{n: "custom_e", u: "https://test.com", d: site.domain, sd: 10})

      assert [%{scroll_depth: 0}, %{scroll_depth: 0}] = get_events(site)
    end

    test "ingests valid scroll_depth for a pageleave", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "pageleave", u: "https://test.com", d: site.domain, sd: 25})

      pageleave = get_events(site) |> Enum.find(&(&1.name == "pageleave"))

      assert pageleave.scroll_depth == 25
    end

    test "ingests scroll_depth as 100 when sd > 100", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "pageleave", u: "https://test.com", d: site.domain, sd: 101})

      pageleave = get_events(site) |> Enum.find(&(&1.name == "pageleave"))

      assert pageleave.scroll_depth == 100
    end

    test "ingests scroll_depth as 255 when sd is a string", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "pageleave", u: "https://test.com", d: site.domain, sd: "1"})

      pageleave = get_events(site) |> Enum.find(&(&1.name == "pageleave"))

      assert pageleave.scroll_depth == 255
    end

    test "ingests scroll_depth as 255 when sd is a negative integer", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "pageleave", u: "https://test.com", d: site.domain, sd: -1})

      pageleave = get_events(site) |> Enum.find(&(&1.name == "pageleave"))

      assert pageleave.scroll_depth == 255
    end

    test "ingests valid scroll_depth for a engagement event", %{conn: conn, site: site} do
      post(conn, "/api/event", %{n: "pageview", u: "https://test.com", d: site.domain})
      post(conn, "/api/event", %{n: "engagement", u: "https://test.com", d: site.domain, sd: 25})

      event = get_events(site) |> Enum.find(&(&1.name == "engagement"))

      assert event.scroll_depth == 25
    end
  end

  describe "acquisition channel tests" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "parses cross network channel", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/?utm_campaign=cross-network",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Cross-network"
    end

    test "parses paid shopping channel based on campaign/medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com/?utm_campaign=shopping&utm_medium=paid",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Shopping"
    end

    test "parses paid shopping channel based on referrer source and medium", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=paid",
        referrer: "https://shopify.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Shopping"
    end

    test "parses paid shopping channel based on referrer utm_source and medium", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=shopify&utm_medium=paid",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Shopping"
    end

    test "parses paid search channel based on referrer and medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=paid",
        referrer: "https://duckduckgo.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Search"
    end

    test "parses paid search channel based on gclid", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?gclid=123identifier",
        referrer: "https://google.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Search"
      assert session.utm_medium == "(gclid)"
      assert session.click_id_param == "gclid"
    end

    test "is not paid search when gclid is present on non-google referrer", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?gclid=123identifier",
        referrer: "https://duckduckgo.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Search"
      assert session.utm_medium == ""
      assert session.click_id_param == "gclid"
    end

    test "does not override utm_medium with (gclid) if link is already tagged", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?gclid=123identifier&utm_medium=paidads",
        referrer: "https://google.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Search"
      assert session.utm_medium == "paidads"
      assert session.click_id_param == "gclid"
    end

    test "parses paid search channel based on msclkid", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?msclkid=123identifier",
        referrer: "https://bing.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Search"
      assert session.utm_medium == "(msclkid)"
      assert session.click_id_param == "msclkid"
    end

    test "is not paid search when msclkid is present on non-bing referrer", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?msclkid=123identifier&utm_medium=cpc",
        referrer: "https://bing.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Search"
      assert session.utm_medium == "cpc"
      assert session.click_id_param == "msclkid"
    end

    test "does not override utm_medium with (msclkid) if link is already tagged", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?gclid=123identifier&utm_medium=paidads",
        referrer: "https://google.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Search"
      assert session.utm_medium == "paidads"
      assert session.click_id_param == "gclid"
    end

    test "parses paid search channel based on utm_source and medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=google&utm_medium=paid",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Search"
      assert session.click_id_param == ""
    end

    test "parses paid social channel based on referrer and medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=paid",
        referrer: "https://tiktok.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Social"
    end

    test "parses paid social channel based on utm_source and medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=tiktok&utm_medium=paid",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Social"
    end

    test "parses paid video channel based on referrer and medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=paid",
        referrer: "https://youtube.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Video"
    end

    test "parses paid video channel based on utm_source and medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=youtube&utm_medium=paid",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Video"
    end

    test "parses display channel", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=banner",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Display"
    end

    test "display channel with gclid", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=display&utm_source=google&gclid=123identifier",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Display"
    end

    test "parses paid other channel", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=cpc",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Paid Other"
    end

    test "parses organic shopping channel from referrer", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://walmart.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Shopping"
    end

    test "parses organic shopping channel from utm_source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=walmart",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Shopping"
    end

    test "parses organic shopping channel from utm_campaign", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_campaign=shop",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Shopping"
    end

    test "parses organic social channel from referrer", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "http://facebook.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Social"
    end

    test "parses organic social channel from utm_source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=twitter",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Social"
    end

    test "parses organic social channel from utm_medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=social",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Social"
    end

    test "parses organic video channel from referrer", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://vimeo.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Video"
    end

    test "parses organic video channel from utm_source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=vimeo",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Video"
    end

    test "parses organic video channel from utm_medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=video",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Video"
    end

    test "parses organic search channel from referrer", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "http://duckduckgo.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Search"
    end

    test "parses organic search channel from utm_source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=duckduckgo",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Organic Search"
    end

    test "parses referral channel from utm_medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=referral",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Referral"
    end

    test "parses email channel from utm_source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=email",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Email"
    end

    test "parses email channel from utm_medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=email",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Email"
    end

    test "parses affiliates channel from utm_medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=affiliate",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Affiliates"
    end

    test "parses audio channel from utm_medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=audio",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Audio"
    end

    test "parses sms channel from utm_source", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=sms",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "SMS"
    end

    test "parses sms channel from utm_medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=sms",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "SMS"
    end

    test "parses mobile push notifications channel from utm_medium with push", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=app-push",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Mobile Push Notifications"
    end

    test "parses mobile push notifications channel from utm_medium", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_medium=example-mobile",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Mobile Push Notifications"
    end

    test "parses referral channel if session starts with a simple referral", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://othersite.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Referral"
    end

    test "parses direct channel if session starts without referrer or utm tags", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.acquisition_channel == "Direct"
    end
  end

  describe "custom source parsing rules" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "threads is Threads", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=threads",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Threads"
      assert session.utm_source == "threads"
      assert session.acquisition_channel == "Organic Social"
    end

    test "ig is Instagram", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=ig",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Instagram"
      assert session.utm_source == "ig"
      assert session.acquisition_channel == "Organic Social"
    end

    test "yt is Youtube", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=yt",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Youtube"
      assert session.utm_source == "yt"
      assert session.acquisition_channel == "Organic Video"
    end

    test "yt-ads is Youtube paid", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=yt-ads",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Youtube"
      assert session.utm_source == "yt-ads"
      assert session.acquisition_channel == "Paid Video"
    end

    test "fb is Facebook", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=fb",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Facebook"
      assert session.utm_source == "fb"
      assert session.acquisition_channel == "Organic Social"
    end

    test "fb-ads is Facebook", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=fb-ads",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Facebook"
      assert session.utm_source == "fb-ads"
      assert session.acquisition_channel == "Paid Social"
    end

    test "fbad is Facebook", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=fbad",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Facebook"
      assert session.utm_source == "fbad"
      assert session.acquisition_channel == "Paid Social"
    end

    test "facebook-ads is Facebook", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=facebook-ads",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Facebook"
      assert session.utm_source == "facebook-ads"
      assert session.acquisition_channel == "Paid Social"
    end

    test "Reddit-ads is Reddit", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=Reddit-ads",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Reddit"
      assert session.utm_source == "Reddit-ads"
      assert session.acquisition_channel == "Paid Social"
    end

    test "google_ads is Google", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=google_ads",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Google"
      assert session.utm_source == "google_ads"
      assert session.acquisition_channel == "Paid Search"
    end

    test "Google-ads is Google", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?source=Google-ads",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Google"
      assert session.utm_source == "Google-ads"
      assert session.acquisition_channel == "Paid Search"
    end

    test "utm_source=Adwords is Google paid search", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=Adwords",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Google"
      assert session.utm_source == "Adwords"
      assert session.acquisition_channel == "Paid Search"
    end

    test "twitter-ads is Twitter", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=twitter-ads",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Twitter"
      assert session.utm_source == "twitter-ads"
      assert session.acquisition_channel == "Paid Social"
    end

    test "android-app://com.reddit.frontpage is Reddit", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "android-app://com.reddit.frontpage",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Reddit"
      assert session.acquisition_channel == "Organic Social"
    end

    test "perplexity.ai is Perplexity", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://perplexity.ai",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Perplexity"
      assert session.acquisition_channel == "Organic Search"
    end

    test "utm_source=perplexity is Perplexity", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=perplexity",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Perplexity"
      assert session.acquisition_channel == "Organic Search"
    end

    test "statics.teams.cdn.office.net is Microsoft Teams", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://statics.teams.cdn.office.net",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Microsoft Teams"
      assert session.acquisition_channel == "Organic Social"
    end

    test "wikipedia domain is resolved as Wikipedia", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://en.wikipedia.org",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Wikipedia"
      assert session.acquisition_channel == "Referral"
    end

    test "ntp.msn.com is Bing", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://ntp.msn.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Bing"
      assert session.acquisition_channel == "Organic Search"
    end

    test "search.brave.com is Brave", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://search.brave.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Brave"
      assert session.acquisition_channel == "Organic Search"
    end

    test "yandex.com.tr is Yandex", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://yandex.com.tr",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Yandex"
      assert session.acquisition_channel == "Organic Search"
    end

    test "yandex.kz is Yandex", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://yandex.kz",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Yandex"
      assert session.acquisition_channel == "Organic Search"
    end

    test "ya.ru is Yandex", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://ya.ru",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Yandex"
      assert session.acquisition_channel == "Organic Search"
    end

    test "yandex.uz is Yandex", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://yandex.uz",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Yandex"
      assert session.acquisition_channel == "Organic Search"
    end

    test "yandex.fr is Yandex", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://yandex.fr",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Yandex"
      assert session.acquisition_channel == "Organic Search"
    end

    test "yandex.eu is Yandex", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://yandex.eu",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Yandex"
      assert session.acquisition_channel == "Organic Search"
    end

    test "yandex.tm is Yandex", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://yandex.tm",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Yandex"
      assert session.acquisition_channel == "Organic Search"
    end

    test "discord.com is Discord", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://discord.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Discord"
      assert session.acquisition_channel == "Organic Social"
    end

    test "discordapp.com is Discord", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://discordapp.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Discord"
      assert session.acquisition_channel == "Organic Social"
    end

    test "canary.discord.com is Discord", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://canary.discord.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Discord"
      assert session.acquisition_channel == "Organic Social"
    end

    test "ptb.discord.com is Discord", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://ptb.discord.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Discord"
      assert session.acquisition_channel == "Organic Social"
    end

    test "www.baidu.com is Baidu", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://baidu.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Baidu"
      assert session.acquisition_channel == "Organic Search"
    end

    test "t.me is Telegram", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://t.me",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Telegram"
      assert session.acquisition_channel == "Organic Social"
    end

    test "webk.telegram.org is Telegram", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://webk.telegram.org",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Telegram"
      assert session.acquisition_channel == "Organic Social"
    end

    test "sogou.com is Sogou", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://sogou.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Sogou"
      assert session.acquisition_channel == "Organic Search"
    end

    test "m.sogou.com is Sogou", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://m.sogou.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Sogou"
      assert session.acquisition_channel == "Organic Search"
    end

    test "wap.sogou.com is Sogou", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://wap.sogou.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Sogou"
      assert session.acquisition_channel == "Organic Search"
    end

    test "linktr.ee is Linktree", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://linktr.ee",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Linktree"
      assert session.acquisition_channel == "Referral"
    end

    test "linktree is Linktree", %{conn: conn, site: site} do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=linktree",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Linktree"
      assert session.acquisition_channel == "Referral"
    end
  end

  describe "custom channel parsing rules" do
    setup do
      site = new_site()
      {:ok, site: site}
    end

    test "hacker news is social channel", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://news.ycombinator.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Hacker News"
      assert session.acquisition_channel == "Organic Social"
    end

    test "yahoo is organic search", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://search.yahoo.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Yahoo!"
      assert session.acquisition_channel == "Organic Search"
    end

    test "gmail is email channel", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://mail.google.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Gmail"
      assert session.acquisition_channel == "Email"
    end

    test "utm_source=newsletter is email channel", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=Newsletter-UK",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Newsletter-UK"
      assert session.acquisition_channel == "Email"
    end

    test "temu.com is shopping channel", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://temu.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "temu.com"
      assert session.acquisition_channel == "Organic Shopping"
    end

    test "utm_source=Telegram is social channel", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com?utm_source=Telegram",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Telegram"
      assert session.acquisition_channel == "Organic Social"
    end

    test "chatgpt.com is search channel", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://chatgpt.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "chatgpt.com"
      assert session.acquisition_channel == "Organic Search"
    end

    test "Slack is social channel", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://app.slack.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Slack"
      assert session.acquisition_channel == "Organic Social"
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

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "producthunt"
      assert session.acquisition_channel == "Organic Social"
    end

    test "github is social", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://github.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "GitHub"
      assert session.acquisition_channel == "Organic Social"
    end

    test "steamcommunity.com is social", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://steamcommunity.com",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "steamcommunity.com"
      assert session.acquisition_channel == "Organic Social"
    end

    test "Vkontakte is social", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://vkontakte.ru",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Vkontakte"
      assert session.acquisition_channel == "Organic Social"
    end

    test "Threads is social", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://threads.net",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Threads"
      assert session.acquisition_channel == "Organic Social"
    end

    test "Ecosia is search", %{
      conn: conn,
      site: site
    } do
      params = %{
        name: "pageview",
        url: "http://example.com",
        referrer: "https://ecosia.org",
        domain: site.domain
      }

      conn =
        conn
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", params)

      session = get_created_session(site)

      assert response(conn, 202) == "ok"
      assert session.referrer_source == "Ecosia"
      assert session.acquisition_channel == "Organic Search"
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

  defp get_created_session(site) do
    Plausible.Session.WriteBuffer.flush()

    ClickhouseRepo.one(
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
