defmodule PlausibleWeb.Api.StatsController.CitiesTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/cities" do
    defp seed(%{site: site}) do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        ),
        build(:pageview,
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        ),
        build(:pageview,
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        ),
        build(:pageview,
          country_code: "EE",
          subdivision1_code: "EE-39",
          city_geoname_id: 591_632
        ),
        build(:pageview,
          country_code: "EE",
          subdivision1_code: "EE-39",
          city_geoname_id: 591_632
        )
      ])
    end

    setup [:create_user, :log_in, :create_site, :create_legacy_site_import, :seed]

    test "returns top cities by new visitors", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/cities?period=day")

      assert json_response(conn, 200)["results"] == [
               %{"code" => 588_409, "country_flag" => "🇪🇪", "name" => "Tallinn", "visitors" => 3},
               %{"code" => 591_632, "country_flag" => "🇪🇪", "name" => "Kärdla", "visitors" => 2}
             ]
    end

    test "when list is filtered returns one city only", %{conn: conn, site: site} do
      filters = Jason.encode!(%{city: "591632"})
      conn = get(conn, "/api/stats/#{site.domain}/cities?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"code" => 591_632, "country_flag" => "🇪🇪", "name" => "Kärdla", "visitors" => 2}
             ]
    end

    test "does not return missing cities from imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:imported_locations, country: "EE", region: "EE-37", city: 588_409),
        build(:imported_locations, country: nil, region: nil, city: 0),
        build(:imported_locations, country: nil, region: nil, city: nil)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/cities?period=day&with_imported=true")

      assert json_response(conn, 200)["results"] == [
               %{"code" => 588_409, "country_flag" => "🇪🇪", "name" => "Tallinn", "visitors" => 4},
               %{"code" => 591_632, "country_flag" => "🇪🇪", "name" => "Kärdla", "visitors" => 2}
             ]
    end
  end
end
