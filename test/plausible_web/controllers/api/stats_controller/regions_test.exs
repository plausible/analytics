defmodule PlausibleWeb.Api.StatsController.RegionsTest do
  use Plausible.Teams.Test
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/regions" do
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
      conn = get(conn, "/api/stats/#{site.domain}/regions?period=day")

      assert json_response(conn, 200)["results"] == [
               %{"code" => "EE-37", "country_flag" => "🇪🇪", "name" => "Harjumaa", "visitors" => 3},
               %{"code" => "EE-39", "country_flag" => "🇪🇪", "name" => "Hiiumaa", "visitors" => 2}
             ]
    end

    test "when list is filtered returns one city only", %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "visit:region", ["EE-39"]]])
      conn = get(conn, "/api/stats/#{site.domain}/regions?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"code" => "EE-39", "country_flag" => "🇪🇪", "name" => "Hiiumaa", "visitors" => 2}
             ]
    end

    test "malicious input - date", %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "visit:region", ["EE-39"]]])
      garbage = "2020-07-30'||DBMS_PIPE.RECEIVE_MESSAGE(CHR(98)||CHR(98)||CHR(98),15)||'"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/regions?period=custom&filters=#{filters}&date=#{garbage}"
        )

      assert resp = response(conn, 400)
      assert resp =~ "Failed to parse 'date' argument."
    end

    test "malicious input - from", %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "visit:region", ["EE-39"]]])
      garbage = "2020-07-30'||DBMS_PIPE.RECEIVE_MESSAGE(CHR(98)||CHR(98)||CHR(98),15)||'"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/regions?period=custom&filters=#{filters}&from=#{garbage}"
        )

      assert resp = response(conn, 400)
      assert resp =~ "Failed to parse 'from' argument."
    end

    test "malicious input - to", %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "visit:region", ["EE-39"]]])
      garbage = "2020-07-30'||DBMS_PIPE.RECEIVE_MESSAGE(CHR(98)||CHR(98)||CHR(98),15)||'"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/regions?period=custom&filters=#{filters}&from=2020-04-01&to=#{garbage}"
        )

      assert resp = response(conn, 400)
      assert resp =~ "Failed to parse 'to' argument."
    end
  end
end
