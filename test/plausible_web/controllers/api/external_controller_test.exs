defmodule PlausibleWeb.Api.ExternalControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.ClickhouseRepo

  defp get_event(domain) do
    Plausible.Event.WriteBuffer.flush()

    ClickhouseRepo.one(
      from e in Plausible.ClickhouseEvent,
        where: e.domain == ^domain,
        order_by: [desc: e.timestamp]
    )
  end

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"

  describe "POST /api/event" do
    test "records the event", %{conn: conn} do
      params = %{
        domain: "external-controller-test-1.com",
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "http://m.facebook.com/",
        screen_width: 1440
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-1.com")

      assert response(conn, 202) == ""
      assert pageview.hostname == "gigride.live"
      assert pageview.domain == "external-controller-test-1.com"
      assert pageview.pathname == "/"
    end

    test "can send to multiple dashboards by listing multiple domains", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "http://m.facebook.com/",
        domain: "test-domain1.com,test-domain2.com",
        screen_width: 1440
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      assert response(conn, 202) == ""
      assert get_event("test-domain1.com")
      assert get_event("test-domain2.com")
    end

    test "www. is stripped from domain", %{conn: conn} do
      params = %{
        name: "custom event",
        url: "http://gigride.live/",
        domain: "www.external-controller-test-2.com"
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-2.com")

      assert pageview.domain == "external-controller-test-2.com"
    end

    test "www. is stripped from hostname", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        domain: "external-controller-test-3.com"
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-3.com")

      assert pageview.hostname == "example.com"
    end

    test "empty path defaults to /", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com",
        domain: "external-controller-test-4.com"
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-4.com")

      assert pageview.pathname == "/"
    end

    test "bots and crawlers are ignored", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        domain: "external-controller-test-5.com"
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", "generic crawler")
      |> post("/api/event", Jason.encode!(params))

      assert get_event("external-controller-test-5.com") == nil
    end

    test "Headless Chrome is ignored", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        domain: "headless-chrome-test.com"
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/85.0.4183.83 Safari/537.36"
      )
      |> post("/api/event", Jason.encode!(params))

      assert get_event("headless-chrome-test.com") == nil
    end

    test "parses user_agent", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        domain: "external-controller-test-6.com"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-6.com")

      assert response(conn, 202) == ""
      assert pageview.operating_system == "Mac"
      assert pageview.operating_system_version == "10.13"
      assert pageview.browser == "Chrome"
      assert pageview.browser_version == "70.0"
    end

    test "parses referrer", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://facebook.com",
        domain: "external-controller-test-7.com"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-7.com")

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "Facebook"
    end

    test "strips trailing slash from referrer", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://facebook.com/page/",
        domain: "external-controller-test-8.com"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-8.com")

      assert response(conn, 202) == ""
      assert pageview.referrer == "facebook.com/page"
      assert pageview.referrer_source == "Facebook"
    end

    test "ignores when referrer is internal", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://gigride.live",
        domain: "external-controller-test-9.com"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-9.com")

      assert response(conn, 202) == ""
      assert pageview.referrer_source == ""
    end

    test "ignores localhost referrer", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "http://localhost:4000/",
        domain: "external-controller-test-10.com"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-10.com")

      assert response(conn, 202) == ""
      assert pageview.referrer_source == ""
    end

    test "parses subdomain referrer", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://blog.gigride.live",
        domain: "external-controller-test-11.com"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-11.com")

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "blog.gigride.live"
    end

    test "referrer is cleaned", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        referrer: "https://www.indiehackers.com/page?query=param#hash",
        domain: "external-controller-test-12.com"
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-12.com")

      assert pageview.referrer == "indiehackers.com/page"
    end

    test "utm_source overrides referrer source", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/?utm_source=betalist",
        referrer: "https://betalist.com/my-produxct",
        domain: "external-controller-test-13.com"
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-13.com")

      assert pageview.referrer_source == "betalist"
    end

    test "utm tags are stored", %{conn: conn} do
      params = %{
        name: "pageview",
        url:
          "http://www.example.com/?utm_medium=ads&utm_source=instagram&utm_campaign=video_story",
        domain: "external-controller-test-utm-tags.com"
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-utm-tags.com")

      assert pageview.utm_medium == "ads"
      assert pageview.utm_source == "instagram"
      assert pageview.utm_campaign == "video_story"
    end

    test "if it's an :unknown referrer, just the domain is used", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://www.indiehackers.com/landing-page-feedback",
        domain: "external-controller-test-14.com"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-14.com")

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "indiehackers.com"
    end

    test "if the referrer is not http or https, it is ignored", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "android-app://com.google.android.gm",
        domain: "external-controller-test-15.com"
      }

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("user-agent", @user_agent)
        |> post("/api/event", Jason.encode!(params))

      pageview = get_event("external-controller-test-15.com")

      assert response(conn, 202) == ""
      assert pageview.referrer_source == ""
    end
  end

  test "screen size is calculated from screen_width", %{conn: conn} do
    params = %{
      name: "pageview",
      url: "http://gigride.live/",
      screen_width: 480,
      domain: "external-controller-test-16.com"
    }

    conn =
      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", Jason.encode!(params))

    pageview = get_event("external-controller-test-16.com")

    assert response(conn, 202) == ""
    assert pageview.screen_size == "Mobile"
  end

  test "screen size is nil if screen_width is missing", %{conn: conn} do
    params = %{
      name: "pageview",
      url: "http://gigride.live/",
      domain: "external-controller-test-17.com"
    }

    conn =
      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", Jason.encode!(params))

    pageview = get_event("external-controller-test-17.com")

    assert response(conn, 202) == ""
    assert pageview.screen_size == ""
  end

  test "can trigger a custom event", %{conn: conn} do
    params = %{
      name: "custom event",
      url: "http://gigride.live/",
      domain: "external-controller-test-18.com"
    }

    conn =
      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", Jason.encode!(params))

    event = get_event("external-controller-test-18.com")

    assert response(conn, 202) == ""
    assert event.name == "custom event"
  end

  test "casts custom props to string", %{conn: conn} do
    params = %{
      name: "Signup",
      url: "http://gigride.live/",
      domain: "custom-prop-test.com",
      props:
        Jason.encode!(%{
          bool_test: true,
          number_test: 12
        })
    }

    conn
    |> put_req_header("content-type", "text/plain")
    |> post("/api/event", Jason.encode!(params))

    event = get_event("custom-prop-test.com")

    assert Map.get(event, :"meta.key") == ["bool_test", "number_test"]
    assert Map.get(event, :"meta.value") == ["true", "12"]
  end

  test "ignores malformed custom props", %{conn: conn} do
    params = %{
      name: "Signup",
      url: "http://gigride.live/",
      domain: "custom-prop-test-2.com",
      props: "\"show-more:button\""
    }

    conn
    |> put_req_header("content-type", "text/plain")
    |> post("/api/event", Jason.encode!(params))

    event = get_event("custom-prop-test-2.com")

    assert Map.get(event, :"meta.key") == []
    assert Map.get(event, :"meta.value") == []
  end

  test "ignores a malformed referrer URL", %{conn: conn} do
    params = %{
      name: "pageview",
      url: "http://gigride.live/",
      referrer: "https:://twitter.com",
      domain: "external-controller-test-19.com"
    }

    conn =
      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", Jason.encode!(params))

    event = get_event("external-controller-test-19.com")

    assert response(conn, 202) == ""
    assert event.referrer == ""
  end

  # Fake data is set up in config/test.exs
  test "looks up the country from the ip address", %{conn: conn} do
    params = %{
      name: "pageview",
      domain: "external-controller-test-20.com",
      url: "http://gigride.live/"
    }

    conn
    |> put_req_header("content-type", "text/plain")
    |> put_req_header("x-forwarded-for", "1.1.1.1")
    |> post("/api/event", Jason.encode!(params))

    pageview = get_event("external-controller-test-20.com")

    assert pageview.country_code == "US"
  end

  test "uses cloudflare's special header for client IP address if present", %{conn: conn} do
    params = %{
      name: "pageview",
      domain: "external-controller-test-cloudflare.com",
      url: "http://gigride.live/"
    }

    conn
    |> put_req_header("content-type", "text/plain")
    |> put_req_header("x-forwarded-for", "0.0.0.0")
    |> put_req_header("cf-connecting-ip", "1.1.1.1")
    |> post("/api/event", Jason.encode!(params))

    pageview = get_event("external-controller-test-cloudflare.com")

    assert pageview.country_code == "US"
  end

  test "URL is decoded", %{conn: conn} do
    params = %{
      name: "pageview",
      url:
        "http://www.example.com/opportunity/category/%D8%AC%D9%88%D8%A7%D8%A6%D8%B2-%D9%88%D9%85%D8%B3%D8%A7%D8%A8%D9%82%D8%A7%D8%AA",
      domain: "external-controller-test-21.com"
    }

    conn
    |> put_req_header("content-type", "text/plain")
    |> post("/api/event", Jason.encode!(params))

    pageview = get_event("external-controller-test-21.com")

    assert pageview.pathname == "/opportunity/category/جوائز-ومسابقات"
  end

  test "accepts shorthand map keys", %{conn: conn} do
    params = %{
      n: "pageview",
      u: "http://www.example.com/opportunity",
      d: "external-controller-test-22.com",
      r: "https://facebook.com/page",
      w: 300
    }

    conn
    |> put_req_header("content-type", "text/plain")
    |> post("/api/event", Jason.encode!(params))

    pageview = get_event("external-controller-test-22.com")

    assert pageview.pathname == "/opportunity"
    assert pageview.referrer_source == "Facebook"
    assert pageview.referrer == "facebook.com/page"
    assert pageview.screen_size == "Mobile"
  end

  test "records hash when in hash mode", %{conn: conn} do
    params = %{
      n: "pageview",
      u: "http://www.example.com/#page-a",
      d: "external-controller-test-23.com",
      h: 1
    }

    conn
    |> put_req_header("content-type", "text/plain")
    |> post("/api/event", Jason.encode!(params))

    pageview = get_event("external-controller-test-23.com")

    assert pageview.pathname == "/#page-a"
  end

  test "decodes URL pathname, fragment and search", %{conn: conn} do
    params = %{
      n: "pageview",
      u:
        "https://test.com/%EF%BA%9D%EF%BB%AD%EF%BA%8E%EF%BA%8B%EF%BA%AF-%EF%BB%AE%EF%BB%A4%EF%BA%B3%EF%BA%8E%EF%BA%92%EF%BB%97%EF%BA%8E%EF%BA%97?utm_source=%25balle%25",
      d: "url-decode-test.com",
      h: 1
    }

    conn
    |> put_req_header("content-type", "text/plain")
    |> post("/api/event", Jason.encode!(params))

    pageview = get_event("url-decode-test.com")

    assert pageview.hostname == "test.com"
    assert pageview.pathname == "/ﺝﻭﺎﺋﺯ-ﻮﻤﺳﺎﺒﻗﺎﺗ"
    assert pageview.utm_source == "%balle%"
  end

  test "can use double quotes in query params", %{conn: conn} do
    q = URI.encode_query(%{"utm_source" => "Something \"quoted\""})

    params = %{
      n: "pageview",
      u: "https://test.com/?" <> q,
      d: "quote-encode-test.com",
      h: 1
    }

    conn
    |> put_req_header("content-type", "text/plain")
    |> post("/api/event", Jason.encode!(params))

    pageview = get_event("quote-encode-test.com")

    assert pageview.utm_source == "Something \"quoted\""
  end

  test "responds 400 when required fields are missing", %{conn: conn} do
    params = %{
      domain: "some-domain.com",
      name: "pageview"
    }

    conn =
      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", Jason.encode!(params))

    assert response(conn, 400) == ""
  end

  describe "GET /api/health" do
    test "returns 200 OK", %{conn: conn} do
      conn = get(conn, "/api/health")

      assert conn.status == 200
    end
  end
end
