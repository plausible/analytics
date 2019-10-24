defmodule PlausibleWeb.Api.ExternalControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"
  @country_code "EE"

  describe "POST /api/page" do
    test "records the pageview", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "http://m.facebook.com/",
        new_visitor: true,
        screen_width: 1440,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> put_req_header("cf-ipcountry", @country_code)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert response(conn, 202) == ""
      assert pageview.hostname == "gigride.live"
      assert pageview.pathname == "/"
      assert pageview.new_visitor == true
      assert pageview.country_code == @country_code
    end

    test "www. is stripped from hostname", %{conn: conn} do
      params = %{
        url: "http://www.example.com/",
        uid: UUID.uuid4(),
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert pageview.hostname == "example.com"
    end

    test "bots and crawlers are ignored", %{conn: conn} do
      params = %{
        url: "http://www.example.com/",
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", "generic crawler")
      |> post("/api/page", Jason.encode!(params))

      pageviews = Repo.all(Plausible.Event)

      assert Enum.count(pageviews) == 0
    end

    test "parses user_agent", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert response(conn, 202) == ""
      assert pageview.operating_system == "Mac"
      assert pageview.browser == "Chrome"
    end

    test "parses referrer", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "https://facebook.com",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "Facebook"
    end

    test "ignores when referrer is internal", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "https://gigride.live",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == nil
    end

    test "ignores localhost referrer", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "http://localhost:4000/",
        new_visitor: true,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == nil
    end

    test "parses subdomain referrer", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "https://blog.gigride.live",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "blog.gigride.live"
    end

    test "referrer is cleaned", %{conn: conn} do
      params = %{
        url: "http://www.example.com/",
        referrer: "https://www.indiehackers.com/page?query=param#hash",
        uid: UUID.uuid4(),
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert pageview.referrer == "indiehackers.com/page"
    end

    test "?ref= query param controls the referrer source", %{conn: conn} do
      params = %{
        url: "http://www.example.com/?wat=wet&ref=traffic-source",
        referrer: "https://www.indiehackers.com/page",
        uid: UUID.uuid4(),
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert pageview.referrer_source == "traffic-source"
    end

    test "?utm_source= query param controls the referrer source", %{conn: conn} do
      params = %{
        url: "http://www.example.com/?wat=wet&utm_source=traffic-source",
        referrer: "https://www.indiehackers.com/page",
        uid: UUID.uuid4(),
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert pageview.referrer_source == "traffic-source"
    end

    test "ignores pageviews from a user blacklist", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "https://blog.gigride.live",
        new_visitor: false,
        uid: "e8150466-7ddb-4771-bcf5-7c58f232e8a6"
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/page", Jason.encode!(params))

      assert Repo.aggregate(Plausible.Event, :count, :id) == 0
    end

    test "if it's an :unknown referrer, just the domain is used", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "https://www.indiehackers.com/landing-page-feedback",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "indiehackers.com"
    end

    test "if the referrer is not http or https, it is ignored", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "android-app://com.google.android.gm",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)

      assert response(conn, 202) == ""
      assert is_nil(pageview.referrer_source)
    end

  end

  test "screen size is calculated from screen_width", %{conn: conn} do
    params = %{
      url: "http://gigride.live/",
      new_visitor: true,
      screen_width: 480,
      uid: UUID.uuid4()
    }

    conn = conn
           |> put_req_header("content-type", "text/plain")
           |> put_req_header("user-agent", @user_agent)
           |> post("/api/page", Jason.encode!(params))

    pageview = Repo.one(Plausible.Event)

    assert response(conn, 202) == ""
    assert pageview.screen_size == "Mobile"
  end

  test "screen size is nil if screen_width is missing", %{conn: conn} do
    params = %{
      url: "http://gigride.live/",
      new_visitor: true,
      uid: UUID.uuid4()
    }

    conn = conn
           |> put_req_header("content-type", "text/plain")
           |> put_req_header("user-agent", @user_agent)
           |> post("/api/page", Jason.encode!(params))

    pageview = Repo.one(Plausible.Event)

    assert response(conn, 202) == ""
    assert pageview.screen_size == nil
  end
end
