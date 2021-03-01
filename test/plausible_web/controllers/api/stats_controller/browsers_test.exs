defmodule PlausibleWeb.Api.StatsController.BrowsersTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_site]

    test "returns top browsers by new visitors", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"name" => "Chrome", "count" => 3, "percentage" => 75},
               %{"name" => "Firefox", "count" => 1, "percentage" => 25}
             ]
    end
  end

  describe "GET /api/stats/:domain/browser-versions" do
    setup [:create_user, :log_in, :create_site]

    test "returns top browser versions by unique visitors", %{conn: conn, site: site} do
      filters = Jason.encode!(%{browser: "Chrome"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/browser-versions?period=day&date=2019-01-01&filters=#{
            filters
          }"
        )

      assert json_response(conn, 200) == [
               %{"name" => "78.0", "count" => 1, "percentage" => 100}
             ]
    end
  end
end
