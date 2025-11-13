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

    test "return revenue metrics for regions breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        ),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 2,
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 3,
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        ),
        build(:pageview,
          user_id: 4,
          country_code: "EE",
          subdivision1_code: "EE-39",
          city_geoname_id: 591_632
        ),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 5,
          country_code: "EE",
          subdivision1_code: "EE-39",
          city_geoname_id: 591_632
        ),
        build(:pageview, user_id: 6),
        build(:event,
          name: "Payment",
          user_id: 6,
          revenue_reporting_amount: Decimal.new("600"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 7),
        build(:event,
          name: "Payment",
          user_id: 7,
          revenue_reporting_amount: nil
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      filters = Jason.encode!([[:is, "event:goal", ["Payment"]]])
      order_by = Jason.encode!([["visitors", "desc"]])

      q = "?filters=#{filters}&order_by=#{order_by}&detailed=true&period=day&page=1&limit=100"

      conn = get(conn, "/api/stats/#{site.domain}/regions#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 33.33,
                 "name" => "Harjumaa",
                 "code" => "EE-37",
                 "country_flag" => "🇪🇪",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$3,000.00",
                   "short" => "$3.0K",
                   "value" => 3000.0
                 },
                 "total_visitors" => 6,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "conversion_rate" => 25.0,
                 "name" => "Hiiumaa",
                 "code" => "EE-39",
                 "country_flag" => "🇪🇪",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "total_visitors" => 4,
                 "visitors" => 1
               }
             ]
    end
  end
end
