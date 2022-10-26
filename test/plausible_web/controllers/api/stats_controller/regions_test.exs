defmodule PlausibleWeb.Api.StatsController.RegionsTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/regions" do
    defp seed(%{site: site}) do
      populate_stats(site, [
        build(:pageview, country_code: "EE", subdivision1_code: "EE-37", city_geoname_id: 588_409),
        build(:pageview, country_code: "EE", subdivision1_code: "EE-37", city_geoname_id: 588_409),
        build(:pageview, country_code: "EE", subdivision1_code: "EE-37", city_geoname_id: 588_409),
        build(:pageview, country_code: "EE", subdivision1_code: "EE-39", city_geoname_id: 591_632),
        build(:pageview, country_code: "EE", subdivision1_code: "EE-39", city_geoname_id: 591_632)
      ])
    end

    setup [:create_user, :log_in, :create_new_site, :add_imported_data, :seed]

    test "returns top cities by new visitors", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/regions?period=day")

      assert json_response(conn, 200) == [
               %{"code" => "EE-37", "country_flag" => "🇪🇪", "name" => "Harjumaa", "visitors" => 3},
               %{"code" => "EE-39", "country_flag" => "🇪🇪", "name" => "Hiiumaa", "visitors" => 2}
             ]
    end

    test "when list is filtered returns one city only", %{conn: conn, site: site} do
      filters = Jason.encode!(%{region: "EE-39"})
      conn = get(conn, "/api/stats/#{site.domain}/regions?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"code" => "EE-39", "country_flag" => "🇪🇪", "name" => "Hiiumaa", "visitors" => 2}
             ]
    end
  end
end
