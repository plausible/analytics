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
                 "count" => 2,
                 "percentage" => 67
               },
               %{
                 "name" => "GBR",
                 "count" => 1,
                 "percentage" => 33
               }
             ]
    end
  end
end
