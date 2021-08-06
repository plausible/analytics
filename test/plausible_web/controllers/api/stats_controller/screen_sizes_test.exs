defmodule PlausibleWeb.Api.StatsController.ScreenSizesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns screen sizes by new visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Laptop")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "count" => 2, "percentage" => 67},
               %{"name" => "Laptop", "count" => 1, "percentage" => 33}
             ]
    end
  end
end
