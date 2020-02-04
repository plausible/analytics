defmodule PlausibleWeb.Api.ExternalControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo

  defp finalize_session(user_id) do
    session_pid = :global.whereis_name(user_id)
    Process.monitor(session_pid)

    assert_receive({:DOWN, session_pid, _, _, _})
  end

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"
  @country_code "EE"

  describe "POST /api/event" do
    test "records the event", %{conn: conn} do
      params = %{
        name: "pageview",
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
             |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert response(conn, 202) == ""
      assert pageview.hostname == "gigride.live"
      assert pageview.domain == "gigride.live"
      assert pageview.pathname == "/"
      assert pageview.new_visitor == true
      assert pageview.country_code == @country_code
    end

    test "can specify the domain", %{conn: conn} do
      params = %{
        name: "custom event",
        url: "http://gigride.live/",
        domain: "some_site.com",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/event", Jason.encode!(params))

      event = Repo.one(Plausible.Event)
      finalize_session(event.user_id)

      assert response(conn, 202) == ""
      assert event.domain == "some_site.com"
    end

    test "www. is stripped from hostname", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        uid: UUID.uuid4(),
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert pageview.hostname == "example.com"
    end

    test "bots and crawlers are ignored", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("user-agent", "generic crawler")
      |> post("/api/event", Jason.encode!(params))

      pageviews = Repo.all(Plausible.Event)

      assert Enum.count(pageviews) == 0
    end

    test "parses user_agent", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert response(conn, 202) == ""
      assert pageview.operating_system == "Mac"
      assert pageview.browser == "Chrome"
    end

    test "parses referrer", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://facebook.com",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "Facebook"
    end

    test "strips trailing slash from referrer", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://facebook.com/page/",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert response(conn, 202) == ""
      assert pageview.referrer == "facebook.com/page"
      assert pageview.referrer_source == "Facebook"
    end

    test "ignores when referrer is internal", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://gigride.live",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == nil
    end

    test "ignores localhost referrer", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "http://localhost:4000/",
        new_visitor: true,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == nil
    end

    test "parses subdomain referrer", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://blog.gigride.live",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "blog.gigride.live"
    end

    test "referrer is cleaned", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/",
        referrer: "https://www.indiehackers.com/page?query=param#hash",
        uid: UUID.uuid4(),
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert pageview.referrer == "indiehackers.com/page"
    end

    test "?ref= query param controls the referrer source", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/?wat=wet&ref=traffic-source",
        referrer: "https://www.indiehackers.com/page",
        uid: UUID.uuid4(),
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert pageview.referrer_source == "traffic-source"
    end

    test "?utm_source= query param controls the referrer source", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://www.example.com/?wat=wet&utm_source=traffic-source",
        referrer: "https://www.indiehackers.com/page",
        uid: UUID.uuid4(),
        new_visitor: true
      }

      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert pageview.referrer_source == "traffic-source"
    end

    test "if it's an :unknown referrer, just the domain is used", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "https://www.indiehackers.com/landing-page-feedback",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert response(conn, 202) == ""
      assert pageview.referrer_source == "indiehackers.com"
    end

    test "if the referrer is not http or https, it is ignored", %{conn: conn} do
      params = %{
        name: "pageview",
        url: "http://gigride.live/",
        referrer: "android-app://com.google.android.gm",
        new_visitor: false,
        uid: UUID.uuid4()
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> put_req_header("user-agent", @user_agent)
             |> post("/api/event", Jason.encode!(params))

      pageview = Repo.one(Plausible.Event)
      finalize_session(pageview.user_id)

      assert response(conn, 202) == ""
      assert is_nil(pageview.referrer_source)
    end

  end

  test "screen size is calculated from screen_width", %{conn: conn} do
    params = %{
      name: "pageview",
      url: "http://gigride.live/",
      new_visitor: true,
      screen_width: 480,
      uid: UUID.uuid4()
    }

    conn = conn
           |> put_req_header("content-type", "text/plain")
           |> put_req_header("user-agent", @user_agent)
           |> post("/api/event", Jason.encode!(params))

    pageview = Repo.one(Plausible.Event)
    finalize_session(pageview.user_id)

    assert response(conn, 202) == ""
    assert pageview.screen_size == "Mobile"
  end

  test "screen size is nil if screen_width is missing", %{conn: conn} do
    params = %{
      name: "pageview",
      url: "http://gigride.live/",
      new_visitor: true,
      uid: UUID.uuid4()
    }

    conn = conn
           |> put_req_header("content-type", "text/plain")
           |> put_req_header("user-agent", @user_agent)
           |> post("/api/event", Jason.encode!(params))

    pageview = Repo.one(Plausible.Event)
    finalize_session(pageview.user_id)

    assert response(conn, 202) == ""
    assert pageview.screen_size == nil
  end

  test "can trigger a custom event", %{conn: conn} do
    params = %{
      name: "custom event",
      url: "http://gigride.live/",
      new_visitor: false,
      uid: UUID.uuid4()
    }

    conn = conn
           |> put_req_header("content-type", "text/plain")
           |> put_req_header("user-agent", @user_agent)
           |> post("/api/event", Jason.encode!(params))

    event = Repo.one(Plausible.Event)
    finalize_session(event.user_id)

    assert response(conn, 202) == ""
    assert event.name == "custom event"
  end
end
