defmodule PlausibleWeb.Api.StatsController.CountriesTest do
  use PlausibleWeb.ConnCase

  defp query_countries(conn, site, opts) do
    always_on_filters = ["is_not", "visit:country", [<<0, 0>>, "ZZ"]]

    params = %{
      "dimensions" => Keyword.get(opts, :dimensions, ["visit:country", "visit:country_name"]),
      "date_range" => Keyword.get(opts, :date_range, "all"),
      "filters" => [
        always_on_filters
        | Keyword.get(opts, :filters, [])
      ],
      "metrics" => Keyword.get(opts, :metrics, ["visitors", "percentage"]),
      "include" => Keyword.get(opts, :include, nil),
      "pagination" => Keyword.get(opts, :pagination, nil),
      "order_by" => Keyword.get(opts, :order_by, nil)
    }

    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  describe "querying for countries with POST /query" do
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

      response1 = query_countries(conn, site, date_range: "day")

      assert response1["results"] == [
               %{"dimensions" => ["EE", "Estonia"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["GB", "United Kingdom"], "metrics" => [1, 33.33]}
             ]

      response2 =
        query_countries(conn, site, date_range: "day", include: %{"imports" => true})

      assert response2["results"] == [
               %{"dimensions" => ["EE", "Estonia"], "metrics" => [3, 60.0]},
               %{"dimensions" => ["GB", "United Kingdom"], "metrics" => [2, 40.0]}
             ]
    end

    test "ignores unknown country code ZZ", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, country_code: "ZZ"),
        build(:imported_locations, country: "ZZ")
      ])

      response =
        query_countries(conn, site, date_range: "day", include: %{"imports" => true})

      assert response["results"] == []
    end

    test "includes anonymous VPN country code A1", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, country_code: "A1"),
        build(:pageview, country_code: "A1"),
        build(:pageview, country_code: "EE")
      ])

      response =
        query_countries(conn, site,
          date_range: "day",
          order_by: [["visitors", "desc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["A1", "Anonymous VPN Service"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["EE", "Estonia"], "metrics" => [1, 33.33]}
             ]
    end

    test "searching for 'Anonymous' returns VPN visitors", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, country_code: "A1"),
        build(:pageview, country_code: "A1"),
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "GB")
      ])

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [["contains", "visit:country_name", ["Anonymous"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["A1", "Anonymous VPN Service"], "metrics" => [2, 100.0]}
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

      insert(:goal, site: site, event_name: "Signup")

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "total_visitors", "group_conversion_rate"],
          order_by: [["visit:country", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["EE", "Estonia"], "metrics" => [1, 2, 50.0]},
               %{"dimensions" => ["GB", "United Kingdom"], "metrics" => [1, 1, 100.0]}
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

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "total_visitors", "group_conversion_rate"],
          order_by: [["group_conversion_rate", "desc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["GB", "United Kingdom"], "metrics" => [1, 1, 100.0]},
               %{"dimensions" => ["EE", "Estonia"], "metrics" => [1, 2, 50.0]}
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

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [["is", "event:props:author", ["John Doe"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["EE", "Estonia"], "metrics" => [1, 100.0]}
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

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [["is_not", "event:props:author", ["John Doe"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["GB", "United Kingdom"], "metrics" => [2, 100.0]}
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

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [["is", "event:props:author", ["(none)"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["GB", "United Kingdom"], "metrics" => [2, 100.0]}
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

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [["is_not", "event:props:author", ["(none)"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["EE", "Estonia"], "metrics" => [2, 100.0]}
             ]
    end

    test "when list is filtered by country returns one country only", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "GB")
      ])

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [["is", "visit:country", ["GB"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["GB", "United Kingdom"], "metrics" => [1, 100.0]}
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

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [
            ["is", "segment", [segment_alfa]],
            ["is", "segment", [segment_beta]]
          ],
          order_by: [["visitors", "desc"], ["visit:country", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["GB", "United Kingdom"], "metrics" => [1, 50.0]},
               %{"dimensions" => ["IE", "Ireland"], "metrics" => [1, 50.0]}
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

      response =
        query_countries(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Payment"]]],
          metrics: [
            "visitors",
            "total_visitors",
            "group_conversion_rate",
            "average_revenue",
            "total_revenue"
          ],
          order_by: [["visitors", "desc"], ["visit:country", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["EE", "Estonia"],
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
                 "dimensions" => ["GB", "United Kingdom"],
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
end
