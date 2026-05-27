defmodule PlausibleWeb.Api.StatsController.OperatingSystemsTest do
  use PlausibleWeb.ConnCase

  defp query_os(conn, site, opts) do
    params = %{
      "dimensions" => Keyword.get(opts, :dimensions, ["visit:os"]),
      "date_range" => Keyword.get(opts, :date_range, "all"),
      "filters" => Keyword.get(opts, :filters, []),
      "metrics" => Keyword.get(opts, :metrics, ["visitors", "percentage"]),
      "include" => Keyword.get(opts, :include, nil),
      "pagination" => Keyword.get(opts, :pagination, nil),
      "order_by" => Keyword.get(opts, :order_by, nil)
    }

    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  describe "GET /api/stats/:domain/operating-systems" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns operating systems by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Android")
      ])

      response = query_os(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["Mac"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["Android"], "metrics" => [1, 33.33]}
             ]
    end

    test "returns (not set) when appropriate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: ""),
        build(:pageview, operating_system: "Linux")
      ])

      response1 = query_os(conn, site, date_range: "day", order_by: [["visit:os", "asc"]])

      assert response1["results"] == [
               %{"dimensions" => ["(not set)"], "metrics" => [1, 50.0]},
               %{"dimensions" => ["Linux"], "metrics" => [1, 50.0]}
             ]

      response2 =
        query_os(conn, site,
          date_range: "day",
          filters: [["is", "visit:os", ["(not set)"]]]
        )

      assert response2["results"] == [
               %{"dimensions" => ["(not set)"], "metrics" => [1, 100.0]}
             ]
    end

    test "select empty imported_operating_systems as (not set), merging with the native (not set)",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 123),
        build(:imported_operating_systems, visitors: 1),
        build(:imported_visitors, visitors: 1)
      ])

      response = query_os(conn, site, date_range: "day", include: %{"imports" => true})

      assert response["results"] == [
               %{"dimensions" => ["(not set)"], "metrics" => [2, 100.0]}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, user_id: 1, operating_system: "Mac"),
        build(:pageview, user_id: 2, operating_system: "Mac"),
        build(:event, user_id: 1, name: "Signup")
      ])

      response =
        query_os(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "total_visitors", "group_conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["Mac"], "metrics" => [1, 2, 50.0]}
             ]
    end

    test "returns operating systems with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          operating_system: "Mac"
        ),
        build(:pageview,
          user_id: 123,
          operating_system: "Mac",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          operating_system: "Windows",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          operating_system: "Android"
        )
      ])

      response =
        query_os(conn, site,
          date_range: "day",
          filters: [["is", "event:props:author", ["John Doe"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Mac"], "metrics" => [1, 100.0]}
             ]
    end

    test "returns screen sizes with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          operating_system: "Windows",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          operating_system: "Windows",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          operating_system: "Mac",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          operating_system: "Android"
        )
      ])

      response =
        query_os(conn, site,
          date_range: "day",
          filters: [["is_not", "event:props:author", ["John Doe"]]],
          order_by: [["visit:os", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Android"], "metrics" => [1, 50.0]},
               %{"dimensions" => ["Mac"], "metrics" => [1, 50.0]}
             ]
    end

    test "returns operating systems by unique visitors with imported data", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Mac"),
        build(:pageview, operating_system: "Android"),
        build(:imported_operating_systems, operating_system: "Mac"),
        build(:imported_operating_systems, operating_system: "Android"),
        build(:imported_visitors, visitors: 2)
      ])

      response1 = query_os(conn, site, date_range: "day")

      assert response1["results"] == [
               %{"dimensions" => ["Mac"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["Android"], "metrics" => [1, 33.33]}
             ]

      response2 = query_os(conn, site, date_range: "day", include: %{"imports" => true})

      assert response2["results"] == [
               %{"dimensions" => ["Mac"], "metrics" => [3, 60.0]},
               %{"dimensions" => ["Android"], "metrics" => [2, 40.0]}
             ]
    end

    test "imported data is ignored when filtering for goal", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, user_id: 1, operating_system: "Mac"),
        build(:pageview, user_id: 2, operating_system: "Mac"),
        build(:imported_operating_systems, operating_system: "Mac"),
        build(:event, user_id: 1, name: "Signup")
      ])

      response =
        query_os(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "total_visitors", "group_conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["Mac"], "metrics" => [1, 2, 50.0]}
             ]
    end

    @tag :ee_only
    test "return revenue metrics for operating systems breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, operating_system: "Mac"),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 2, operating_system: "Mac"),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 3, operating_system: "Mac"),
        build(:pageview, user_id: 4, operating_system: "Android"),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 5, operating_system: "Android"),
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

      response =
        query_os(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Payment"]]],
          metrics: [
            "visitors",
            "total_visitors",
            "group_conversion_rate",
            "average_revenue",
            "total_revenue"
          ],
          order_by: [["visitors", "desc"], ["visit:os", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["(not set)"],
                 "metrics" => [
                   2,
                   2,
                   100.0,
                   %{
                     "currency" => "USD",
                     "long" => "$600.00",
                     "short" => "$600.0",
                     "value" => 600.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$600.00",
                     "short" => "$600.0",
                     "value" => 600.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["Mac"],
                 "metrics" => [
                   2,
                   3,
                   66.67,
                   %{
                     "currency" => "USD",
                     "long" => "$1,500.00",
                     "short" => "$1.5K",
                     "value" => 1500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$3,000.00",
                     "short" => "$3.0K",
                     "value" => 3000.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["Android"],
                 "metrics" => [
                   1,
                   2,
                   50.0,
                   %{
                     "currency" => "USD",
                     "long" => "$500.00",
                     "short" => "$500.0",
                     "value" => 500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$500.00",
                     "short" => "$500.0",
                     "value" => 500.0
                   }
                 ]
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/operating-system-versions" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns top OS versions by unique visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.15"
        ),
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.16"
        ),
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "10.16"
        ),
        build(:pageview,
          operating_system: "Android",
          operating_system_version: "4"
        )
      ])

      response =
        query_os(conn, site,
          date_range: "day",
          dimensions: ["visit:os", "visit:os_version"],
          filters: [["is", "visit:os", ["Mac"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Mac", "10.16"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["Mac", "10.15"], "metrics" => [1, 33.33]}
             ]
    end

    test "returns OS and version with additional metrics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac", operating_system_version: "14")
      ])

      response =
        query_os(conn, site,
          date_range: "day",
          dimensions: ["visit:os", "visit:os_version"],
          filters: [["is", "visit:os", ["Mac"]]],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["Mac", "14"], "metrics" => [1, 100, 0, 100.0]}
             ]
    end

    test "with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "11",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          operating_system: "Mac",
          operating_system_version: "12",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:imported_operating_systems,
          date: ~D[2021-01-01],
          operating_system: "Mac",
          operating_system_version: "11",
          visitors: 5
        ),
        build(:imported_operating_systems,
          date: ~D[2021-01-01],
          operating_system: "Windows",
          operating_system_version: "11",
          visitors: 3
        ),
        build(:imported_operating_systems, date: ~D[2021-01-01], visitors: 10),
        build(:imported_visitors, date: ~D[2021-01-01], visitors: 18)
      ])

      response =
        query_os(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          dimensions: ["visit:os", "visit:os_version"],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["(not set)", "(not set)"], "metrics" => [10, 50.0]},
               %{"dimensions" => ["Mac", "11"], "metrics" => [6, 30.0]},
               %{"dimensions" => ["Windows", "11"], "metrics" => [3, 15.0]},
               %{"dimensions" => ["Mac", "12"], "metrics" => [1, 5.0]}
             ]
    end
  end
end
