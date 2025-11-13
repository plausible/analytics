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
      filters = Jason.encode!([[:is, "visit:city", ["591632"]]])
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

    test "return revenue metrics for cities breakdown", %{conn: conn, site: site} do
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

      conn = get(conn, "/api/stats/#{site.domain}/cities#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 33.33,
                 "name" => "Tallinn",
                 "code" => 588_409,
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
                 "name" => "Kärdla",
                 "code" => 591_632,
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
