defmodule PlausibleWeb.Api.StatsController.CountriesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/countries" do
    setup [:create_user, :log_in, :create_new_site]

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
        )
      ])

      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day")

      assert json_response(conn, 200) == [
               %{
                 "name" => "EST",
                 "visitors" => 2,
                 "percentage" => 67
               },
               %{
                 "name" => "GBR",
                 "visitors" => 1,
                 "percentage" => 33
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
                 "name" => "GBR",
                 "total_visitors" => 1,
                 "visitors" => 1,
                 "conversion_rate" => 100.0
               },
               %{
                 "name" => "EST",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end
  end
end
