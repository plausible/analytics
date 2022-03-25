defmodule PlausibleWeb.Api.StatsController.ScreenSizesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

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

    test "returns screen sizes by new visitors with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Laptop")
      ])

      populate_stats(site, [
        build(:imported_devices, device: "Mobile"),
        build(:imported_devices, device: "Laptop")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 67},
               %{"name" => "Laptop", "visitors" => 1, "percentage" => 33}
             ]

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&with_imported=true")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 40},
               %{"name" => "Laptop", "visitors" => 2, "percentage" => 40},
               %{"name" => "Mobile", "visitors" => 1, "percentage" => 20}
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
                 "conversion_rate" => 50.0
               }
             ]
    end
  end
end
