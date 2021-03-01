defmodule PlausibleWeb.Api.StatsController.ScreenSizesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_site]

    test "returns screen sizes by new visitors", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "count" => 2, "percentage" => 50},
               %{"name" => "Laptop", "count" => 1, "percentage" => 25},
               %{"name" => "Mobile", "count" => 1, "percentage" => 25}
             ]
    end
  end
end
