defmodule PlausibleWeb.Api.StatsController.BrowsersTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_site]

    test "returns top browsers by new visitors", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"name" => "Chrome", "count" => 2, "percentage" => 67},
               %{"name" => "Firefox", "count" => 1, "percentage" => 33}
             ]
    end
  end
end
