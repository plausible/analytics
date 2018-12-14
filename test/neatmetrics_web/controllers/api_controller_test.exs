defmodule NeatmetricsWeb.ApiControllerTest do
  use NeatmetricsWeb.ConnCase
  use Neatmetrics.Repo

  describe "POST /api/page" do
    test "records the pageview", %{conn: conn} do
      params = %{
        url: "http://gigride.live/",
        referrer: "http://m.facebook.com/",
        user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36",
        screen_width: 1440,
        screen_height: 900
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> post("/api/page", Jason.encode!(params))

      pageview = Neatmetrics.Repo.one(Neatmetrics.Pageview)

      assert response(conn, 202) == ""
      assert pageview.hostname == "gigride.live"
      assert pageview.pathname == "/"
      assert pageview.user_agent == params[:user_agent]
      assert pageview.screen_width == params[:screen_width]
      assert pageview.screen_height == params[:screen_height]
    end

    test "URL is required", %{conn: conn} do
      params = %{
        referrer: "http://m.facebook.com/",
      }

      conn = conn
             |> put_req_header("content-type", "text/plain")
             |> post("/api/page", Jason.encode!(params))

      assert response(conn, 400) == ""
    end
  end
end
