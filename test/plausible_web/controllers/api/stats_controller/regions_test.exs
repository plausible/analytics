defmodule PlausibleWeb.Api.StatsController.RegionsTest do
  use PlausibleWeb.ConnCase

  defp query_regions(conn, site, opts) do
    always_on_filters = ["is_not", "visit:region", [""]]

    params = %{
      "dimensions" => Keyword.get(opts, :dimensions, ["visit:region", "visit:region_name"]),
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

  describe "querying for regions with POST /query" do
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

    test "returns top regions by visitors", %{conn: conn, site: site} do
      response = query_regions(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["EE-37", "Harjumaa"], "metrics" => [3, 60.0]},
               %{"dimensions" => ["EE-39", "Hiiumaa"], "metrics" => [2, 40.0]}
             ]
    end

    test "when list is filtered returns one region only", %{conn: conn, site: site} do
      response =
        query_regions(conn, site,
          date_range: "day",
          filters: [["is", "visit:region", ["EE-39"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["EE-39", "Hiiumaa"], "metrics" => [2, 100.0]}
             ]
    end

    @tag :ee_only
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

      response =
        query_regions(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Payment"]]],
          metrics: [
            "visitors",
            "total_visitors",
            "group_conversion_rate",
            "average_revenue",
            "total_revenue"
          ],
          order_by: [["visitors", "desc"], ["visit:region", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["EE-37", "Harjumaa"],
                 "metrics" => [
                   2,
                   6,
                   33.33,
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
                 "dimensions" => ["EE-39", "Hiiumaa"],
                 "metrics" => [
                   1,
                   4,
                   25.0,
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
