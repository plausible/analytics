defmodule PlausibleWeb.Api.StatsController.CountriesTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/countries" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns top countries by new visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "GB"),
        build(:imported_locations, country: "EE"),
        build(:imported_locations, country: "GB"),
        build(:imported_visitors, visitors: 2)
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/countries?period=day")

      assert json_response(conn1, 200)["results"] == [
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "visitors" => 2,
                 "percentage" => 66.67
               },
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 1,
                 "percentage" => 33.33
               }
             ]

      conn2 = get(conn, "/api/stats/#{site.domain}/countries?period=day&with_imported=true")

      assert json_response(conn2, 200)["results"] == [
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

    test "ignores unknown country code ZZ", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, country_code: "ZZ"),
        build(:imported_locations, country: "ZZ")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&with_imported=true")

      assert json_response(conn, 200)["results"] == []
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

      insert(:goal, site: site, event_name: "Signup")

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               },
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "total_visitors" => 1,
                 "visitors" => 1,
                 "conversion_rate" => 100.0
               }
             ]
    end

    test "handles conversion_rate sort directive", %{conn: conn, site: site} do
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

      insert(:goal, site: site, event_name: "Signup")

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}&order_by=#{Jason.encode!([["conversion_rate", "desc"]])}"
        )

      assert json_response(conn, 200)["results"] == [
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

    test "returns top countries with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          country_code: "EE"
        ),
        build(:pageview,
          user_id: 123,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          country_code: "GB",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          country_code: "US"
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["John Doe"]]])
      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "visitors" => 1,
                 "percentage" => 100
               }
             ]
    end

    test "returns top countries with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          country_code: "GB",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          country_code: "GB"
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["John Doe"]]])
      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 2,
                 "percentage" => 100
               }
             ]
    end

    test "returns top countries with :is (none) filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          country_code: "GB",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:pageview,
          country_code: "GB"
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["(none)"]]])
      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 2,
                 "percentage" => 100
               }
             ]
    end

    test "returns top countries with :is_not (none) filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": [""]
        ),
        build(:pageview,
          country_code: "GB",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:pageview,
          country_code: "GB"
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["(none)"]]])
      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "visitors" => 2,
                 "percentage" => 100
               }
             ]
    end

    test "when list is filtered by country returns one country only", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "GB")
      ])

      filters = Jason.encode!([[:is, "visit:country", ["GB"]]])
      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 1,
                 "percentage" => 100
               }
             ]
    end

    test "handles multiple segment filters", %{conn: conn, site: site, user: user} do
      %{id: segment_alfa} =
        insert(:segment,
          site_id: site.id,
          owner_id: user.id,
          name: "Ireland and Britain (excl London)",
          type: :site,
          segment_data: %{
            "filters" => [
              ["is", "visit:country", ["IE", "GB"]],
              ["is_not", "visit:city", [2_643_743]]
            ]
          }
        )

      %{id: segment_beta} =
        insert(:segment,
          site_id: site.id,
          owner_id: user.id,
          name: "Entered on root or blog",
          type: :personal,
          segment_data: %{
            "filters" => [
              ["is", "visit:entry_page", ["/", "/blog"]]
            ]
          }
        )

      populate_stats(site, [
        build(:pageview, country_code: "EE"),
        build(:pageview,
          country_code: "GB",
          # London
          city_geoname_id: 2_643_743
        ),
        build(:pageview,
          country_code: "GB",
          # London
          city_geoname_id: 2_643_743
        ),
        build(:pageview, country_code: "GB"),
        build(:pageview, country_code: "IE", pathname: "/other"),
        build(:pageview, country_code: "IE")
      ])

      filters =
        Jason.encode!([["is", "segment", [segment_alfa]], ["is", "segment", [segment_beta]]])

      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 1,
                 "percentage" => 50
               },
               %{
                 "code" => "IE",
                 "alpha_3" => "IRL",
                 "name" => "Ireland",
                 "flag" => "🇮🇪",
                 "visitors" => 1,
                 "percentage" => 50
               }
             ]
    end

    @tag :ee_only
    test "return revenue metrics for countries breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          country_code: "EE"
        ),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 2,
          country_code: "EE"
        ),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 3,
          country_code: "EE"
        ),
        build(:pageview,
          user_id: 4,
          country_code: "GB"
        ),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview,
          user_id: 5,
          country_code: "GB"
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

      conn = get(conn, "/api/stats/#{site.domain}/countries#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 66.67,
                 "name" => "Estonia",
                 "alpha_3" => "EST",
                 "code" => "EE",
                 "flag" => "🇪🇪",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$3,000.00",
                   "short" => "$3.0K",
                   "value" => 3000.0
                 },
                 "total_visitors" => 3,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "conversion_rate" => 50.0,
                 "name" => "United Kingdom",
                 "alpha_3" => "GBR",
                 "code" => "GB",
                 "flag" => "🇬🇧",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$500.00",
                   "short" => "$500.0",
                   "value" => 500.0
                 },
                 "total_visitors" => 2,
                 "visitors" => 1
               }
             ]
    end
  end
end
