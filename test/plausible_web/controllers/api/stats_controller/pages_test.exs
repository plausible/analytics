defmodule PlausibleWeb.Api.StatsController.PagesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/pages" do
    setup [:create_user, :log_in, :create_site]

    test "returns top pages sources by pageviews", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"count" => 2, "name" => "/"},
               %{"count" => 2, "name" => "/register"},
               %{"count" => 1, "name" => "/contact"},
               %{"count" => 1, "name" => "/irrelevant"}
             ]
    end

    test "calculates bounce rate for pages", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2019-01-01&include=bounce_rate"
        )

      assert json_response(conn, 200) == [
               %{"count" => 2, "name" => "/", "bounce_rate" => 33.0},
               %{"bounce_rate" => nil, "count" => 2, "name" => "/register"},
               %{"bounce_rate" => nil, "count" => 1, "name" => "/contact"},
               %{"bounce_rate" => nil, "count" => 1, "name" => "/irrelevant"}
             ]
    end
  end
end
