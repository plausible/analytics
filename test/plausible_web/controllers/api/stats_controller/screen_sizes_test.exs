defmodule PlausibleWeb.Api.StatsController.ScreenSizesTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/screen-sizes" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns screen sizes by new visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Laptop")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "Laptop", "visitors" => 1, "percentage" => 33.33}
             ]
    end

    test "returns bounce_rate and visit_duration when detailed=true", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          timestamp: ~N[2021-01-01 12:00:00],
          screen_size: "Desktop"
        ),
        build(:pageview,
          user_id: 123,
          timestamp: ~N[2021-01-01 12:10:00],
          screen_size: "Desktop"
        ),
        build(:pageview, timestamp: ~N[2021-01-01 12:00:00], screen_size: "Desktop"),
        build(:pageview, timestamp: ~N[2021-01-01 12:00:00], screen_size: "Laptop")
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/screen-sizes?period=day&date=2021-01-01&detailed=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "Desktop",
                 "visitors" => 2,
                 "bounce_rate" => 50,
                 "visit_duration" => 300,
                 "percentage" => 66.67
               },
               %{
                 "name" => "Laptop",
                 "visitors" => 1,
                 "bounce_rate" => 100,
                 "visit_duration" => 0,
                 "percentage" => 33.33
               }
             ]
    end

    test "returns screen sizes for user making multiple sessions", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          screen_size: "Desktop",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          screen_size: "Laptop",
          timestamp: ~N[2021-01-01 05:00:00]
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/screen-sizes", %{
          "period" => "day",
          "date" => "2021-01-01"
        })

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Desktop", "visitors" => 1, "percentage" => 100},
               %{"name" => "Laptop", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "returns (not set) when appropriate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          screen_size: ""
        ),
        build(:pageview,
          screen_size: "Desktop"
        )
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day")

      assert json_response(conn1, 200)["results"] == [
               %{"name" => "(not set)", "visitors" => 1, "percentage" => 50},
               %{"name" => "Desktop", "visitors" => 1, "percentage" => 50}
             ]

      filters = Jason.encode!([[:is, "visit:screen", ["(not set)"]]])
      conn2 = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn2, 200)["results"] == [
               %{"name" => "(not set)", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "select empty imported_devices as (not set), merging with the native (not set)", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, user_id: 123),
        build(:imported_devices, visitors: 1),
        build(:imported_visitors, visitors: 1)
      ])

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&with_imported=true")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "(not set)", "visitors" => 2, "percentage" => 100.0}
             ]
    end

    test "returns screen sizes with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop"
        ),
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          screen_size: "Mobile",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          screen_size: "Tablet"
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["John Doe"]]])
      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Desktop", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "returns screen sizes with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          screen_size: "Mobile",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          screen_size: "Tablet"
        )
      ])

      filters = Jason.encode!([["is_not", "event:props:author", ["John Doe"]]])
      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Mobile", "visitors" => 1, "percentage" => 50},
               %{"name" => "Tablet", "visitors" => 1, "percentage" => 50}
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
        build(:imported_devices, device: "Laptop"),
        build(:imported_visitors, visitors: 2)
      ])

      conn1 = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day")

      assert json_response(conn1, 200)["results"] == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "Laptop", "visitors" => 1, "percentage" => 33.33}
             ]

      conn2 = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&with_imported=true")

      assert json_response(conn2, 200)["results"] == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 40},
               %{"name" => "Laptop", "visitors" => 2, "percentage" => 40},
               %{"name" => "Mobile", "visitors" => 1, "percentage" => 20}
             ]
    end

    test "returns screen sizes when filtering by imported screen size", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:imported_devices, device: "Desktop"),
        build(:imported_devices, device: "Laptop"),
        build(:imported_visitors, visitors: 2)
      ])

      filters = Jason.encode!([[:is, "visit:screen", ["Desktop"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/screen-sizes?filters=#{filters}&period=day&with_imported=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 100.0}
             ]
    end

    test "returns screen sizes for user making multiple sessions by no of visitors with imported data",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          screen_size: "Desktop",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          screen_size: "Laptop",
          timestamp: ~N[2021-01-01 05:00:00]
        )
      ])

      populate_stats(site, [
        build(:imported_devices, device: "Desktop", date: ~D[2021-01-01]),
        build(:imported_devices, device: "Laptop", date: ~D[2021-01-01]),
        build(:imported_visitors, visitors: 1, date: ~D[2021-01-01])
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/screen-sizes", %{
          "period" => "day",
          "date" => "2021-01-01",
          "with_imported" => "true"
        })

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 100},
               %{"name" => "Laptop", "visitors" => 2, "percentage" => 100}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, user_id: 1, screen_size: "Desktop"),
        build(:pageview, user_id: 2, screen_size: "Desktop"),
        build(:event, user_id: 1, name: "Signup")
      ])

      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "Desktop",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns screen sizes with not_member filter type", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, referrer_source: "Google", screen_size: "Desktop"),
        build(:pageview, referrer_source: "Bad source", screen_size: "Desktop"),
        build(:pageview, referrer_source: "Google", screen_size: "Desktop"),
        build(:pageview, referrer_source: "Twitter", screen_size: "Mobile"),
        build(:pageview,
          referrer_source: "Second bad source",
          screen_size: "Mobile"
        )
      ])

      filters = Jason.encode!([["is_not", "visit:source", ["Bad source", "Second bad source"]]])

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200)["results"] == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 66.67},
               %{"name" => "Mobile", "visitors" => 1, "percentage" => 33.33}
             ]
    end

    @tag :ee_only
    test "return revenue metrics for screen sizes breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, screen_size: "Mobile"),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 2, screen_size: "Mobile"),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 3, screen_size: "Mobile"),
        build(:pageview, user_id: 4, screen_size: "Desktop"),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 5, screen_size: "Desktop"),
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

      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes#{q}")

      assert json_response(conn, 200)["results"] == [
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$600.00",
                   "short" => "$600.0",
                   "value" => 600.0
                 },
                 "conversion_rate" => 100.0,
                 "name" => "(not set)",
                 "total_revenue" => %{
                   "currency" => "USD",
                   "long" => "$600.00",
                   "short" => "$600.0",
                   "value" => 600.0
                 },
                 "total_visitors" => 2,
                 "visitors" => 2
               },
               %{
                 "average_revenue" => %{
                   "currency" => "USD",
                   "long" => "$1,500.00",
                   "short" => "$1.5K",
                   "value" => 1500.0
                 },
                 "conversion_rate" => 66.67,
                 "name" => "Mobile",
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
                 "name" => "Desktop",
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
