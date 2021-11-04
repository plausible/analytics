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
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 67},
               %{"name" => "Laptop", "visitors" => 1, "percentage" => 33}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, screen_size: "Desktop"),
        build(:pageview, user_id: 2, screen_size: "Desktop"),
        build(:event, user_id: 1, name: "Signup")
      ])

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "Desktop",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "percentage" => 100,
                 "conversion_rate" => 50.0
               }
             ]
    end
  end
end
