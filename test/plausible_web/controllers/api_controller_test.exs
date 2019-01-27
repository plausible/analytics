defmodule PlausibleWeb.ApiControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"

  describe "POST /api/page" do
    test "records the pageview", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "http://m.facebook.com/",
        new_visitor: true,
        screen_width: 1440,
        screen_height: 900,
        sid: "123",
        uid: "321"
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Pageview)

      assert response(conn, 202) == ""
      assert pageview.hostname == "gigride.live"
      assert pageview.pathname == "/"
      assert pageview.new_visitor == true
      assert pageview.user_agent == @user_agent
      assert pageview.screen_width == params[:screen_width]
      assert pageview.screen_height == params[:screen_height]
      assert pageview.screen_size == "1440x900"
    end

    test "www. is stripped from hostname", %{conn: conn} do
      params = %{
        url: "http://www.example.com/",
        sid: "123",
        uid: "321",
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Pageview)

      assert pageview.hostname == "example.com"
    end

    test "bots and crawlers are ignored", %{conn: conn} do
      params = %{
        url: "http://www.example.com/",
        sid: "123",
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", "generic crawler")
      |> post("/api/page", Jason.encode!(params))

      pageviews = Repo.all(Plausible.Pageview)

      assert Enum.count(pageviews) == 0
    end

    test "parses user_agent", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        new_visitor: false,
        sid: "123",
        uid: "321"
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Pageview)

      assert response(conn, 202) == ""
      assert pageview.device_type == "Desktop"
      assert pageview.operating_system == "Mac"
      assert pageview.browser == "Chrome"
    end

    test "parses referrer", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "https://facebook.com",
        new_visitor: false,
        sid: "123",
        uid: "321"
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Pageview)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "Facebook"
    end

    test "if it's an :unknown referrer, just the domain is used", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "https://indiehackers.com",
        new_visitor: false,
        sid: "123",
        uid: "321"
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Pageview)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "indiehackers.com"
    end

    test "if the referrer is not http or https, it is considered unknown", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "android-app://com.google.android.gm",
        new_visitor: false,
        sid: "123",
        uid: "321"
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/page", Jason.encode!(params))

      pageview = Repo.one(Plausible.Pageview)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "Unknown"
    end

  end
end
