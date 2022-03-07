defmodule PlausibleWeb.Api.StatsController.CountriesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/countries" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "returns top countries by new visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE"
        ),
        build(:pageview,
          country_code: "EE"
        ),
        build(:pageview,
          country_code: "GB"
        ),
        build(:imported_locations,
          country: "EE"
        ),
        build(:imported_locations,
          country: "GB"
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day")

      assert json_response(conn, 200) == [
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "visitors" => 2,
                 "percentage" => 67
               },
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 1,
                 "percentage" => 33
               }
             ]

      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&with_imported=true")

      assert json_response(conn, 200) == [
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "visitors" => 3,
                 "percentage" => 60
               },
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 2,
                 "percentage" => 40
               }
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          country_code: "EE"
        ),
        build(:event, user_id: 1, name: "Signup"),
        build(:pageview,
          user_id: 2,
          country_code: "EE"
        ),
        build(:pageview,
          user_id: 3,
          country_code: "GB"
        ),
        build(:event, user_id: 3, name: "Signup")
      ])

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "total_visitors" => 1,
                 "visitors" => 1,
                 "conversion_rate" => 100.0
               },
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end
  end
end
