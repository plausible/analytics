defmodule PlausibleWeb.Api.StatsController.CustomPropBreakdownTest do
  use PlausibleWeb.ConnCase

  defp query_props(conn, site, prop_key, opts \\ []) do
    params = %{
      "dimensions" => ["event:props:#{prop_key}"],
      "date_range" => Keyword.get(opts, :date_range, "day"),
      "filters" => Keyword.get(opts, :filters, []),
      "metrics" => Keyword.get(opts, :metrics, ["visitors", "events", "percentage"]),
      "include" => Keyword.get(opts, :include, nil),
      "pagination" => Keyword.get(opts, :pagination, nil),
      "order_by" => Keyword.get(opts, :order_by, nil)
    }

    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  describe "GET /api/stats/:domain/custom-prop-values/:prop_key" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns breakdown by a custom property", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, user_id: 123, "meta.key": [prop_key], "meta.value": ["Lotte"]),
        build(:pageview, user_id: 123, "meta.key": [prop_key], "meta.value": ["Lotte"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Sipsik"])
      ])

      response =
        query_props(conn, site, prop_key,
          order_by: [["visitors", "desc"], ["event:props:#{prop_key}", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["K2sna Kalle"], "metrics" => [2, 2, 50.0]},
               %{"dimensions" => ["Lotte"], "metrics" => [1, 2, 25.0]},
               %{"dimensions" => ["Sipsik"], "metrics" => [1, 1, 25.0]}
             ]
    end

    test "ignores imported data when calculating percentage", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:imported_visitors, visitors: 2)
      ])

      response = query_props(conn, site, prop_key, include: %{"imports" => true})

      assert response["results"] == [
               %{"dimensions" => ["K2sna Kalle"], "metrics" => [1, 1, 100.0]}
             ]
    end

    test "returns (none) values in the breakdown", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview)
      ])

      response = query_props(conn, site, prop_key)

      assert response["results"] == [
               %{"dimensions" => ["K2sna Kalle"], "metrics" => [2, 2, 66.67]},
               %{"dimensions" => ["(none)"], "metrics" => [1, 1, 33.33]}
             ]
    end

    test "(none) value is included in pagination", %{conn: conn, site: site} do
      prop_key = "kaksik"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Teet"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Teet"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Tiit"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Tiit"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Tiit"]),
        build(:pageview)
      ])

      response1 = query_props(conn, site, prop_key, pagination: %{"limit" => 2, "offset" => 0})
      response2 = query_props(conn, site, prop_key, pagination: %{"limit" => 2, "offset" => 2})

      assert response1["results"] == [
               %{"dimensions" => ["Tiit"], "metrics" => [3, 3, 50.0]},
               %{"dimensions" => ["Teet"], "metrics" => [2, 2, 33.33]}
             ]

      assert response2["results"] == [
               %{"dimensions" => ["(none)"], "metrics" => [1, 1, 16.67]}
             ]
    end
  end

  describe "GET /api/stats/:domain/custom-prop-values/:prop_key - with goal filter" do
    setup [:create_user, :log_in, :create_site]

    test "returns property breakdown for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      response =
        query_props(conn, site, "variant",
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["B"], "metrics" => [2, 2, 33.33]},
               %{"dimensions" => ["A"], "metrics" => [1, 1, 16.67]}
             ]
    end

    test "returns (none) values in property breakdown for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      response =
        query_props(conn, site, "variant",
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["(none)"], "metrics" => [2, 2, 33.33]},
               %{"dimensions" => ["A"], "metrics" => [1, 1, 16.67]}
             ]
    end

    test "does not return (none) value in property breakdown with is filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      response =
        query_props(conn, site, "cost",
          filters: [
            ["is", "event:goal", ["Purchase"]],
            ["is", "event:props:cost", ["0"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["0"], "metrics" => [1, 1, 50.0]}
             ]
    end

    test "returns only (none) value in property breakdown with is (none) filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      response =
        query_props(conn, site, "cost",
          filters: [
            ["is", "event:goal", ["Purchase"]],
            ["is", "event:props:cost", ["(none)"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["(none)"], "metrics" => [1, 1, 50.0]}
             ]
    end

    test "returns (none) value in property breakdown with is_not filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      response =
        query_props(conn, site, "cost",
          filters: [
            ["is", "event:goal", ["Purchase"]],
            ["is_not", "event:props:cost", ["0"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["20"], "metrics" => [2, 2, 50.0]},
               %{"dimensions" => ["(none)"], "metrics" => [1, 1, 25.0]}
             ]
    end

    test "does not return (none) value in property breakdown with is_not (none) filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      response =
        query_props(conn, site, "cost",
          filters: [
            ["is", "event:goal", ["Purchase"]],
            ["is_not", "event:props:cost", ["(none)"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["0"], "metrics" => [1, 1, 50.0]}
             ]
    end

    test "does not return (none) value in property breakdown with member filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      response =
        query_props(conn, site, "cost",
          filters: [
            ["is", "event:goal", ["Purchase"]],
            ["is", "event:props:cost", ["0", "1"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["1"], "metrics" => [2, 2, 50.0]},
               %{"dimensions" => ["0"], "metrics" => [1, 1, 25.0]}
             ]
    end

    test "returns (none) value in property breakdown with member filter including a (none) value",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      response =
        query_props(conn, site, "cost",
          filters: [
            ["is", "event:goal", ["Purchase"]],
            ["is", "event:props:cost", ["1", "(none)"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["1"], "metrics" => [2, 2, 50.0]},
               %{"dimensions" => ["(none)"], "metrics" => [1, 1, 25.0]}
             ]
    end

    test "returns (none) value in property breakdown with not_member filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0.01"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      response =
        query_props(conn, site, "cost",
          filters: [
            ["is", "event:goal", ["Purchase"]],
            ["is_not", "event:props:cost", ["0", "0.01"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["20"], "metrics" => [2, 2, 40.0]},
               %{"dimensions" => ["(none)"], "metrics" => [1, 1, 20.0]}
             ]
    end

    test "does not return (none) value in property breakdown with not_member filter including a (none) value",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      response =
        query_props(conn, site, "cost",
          filters: [
            ["is", "event:goal", ["Purchase"]],
            ["is_not", "event:props:cost", ["0", "(none)"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["20"], "metrics" => [2, 2, 50.0]}
             ]
    end

    test "returns property breakdown with a pageview goal filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:pageview, pathname: "/register", "meta.key": ["variant"], "meta.value": ["A"])
      ])

      insert(:goal, %{site: site, page_path: "/register"})

      response =
        query_props(conn, site, "variant",
          filters: [["is", "event:goal", ["Visit /register"]]],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["A"], "metrics" => [2, 2, 50.0]},
               %{"dimensions" => ["(none)"], "metrics" => [1, 1, 25.0]}
             ]
    end

    test "property breakdown with prop filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1),
        build(:event, user_id: 1, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:pageview, user_id: 2),
        build(:event, user_id: 2, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      response =
        query_props(conn, site, "variant",
          filters: [
            ["is", "event:goal", ["Signup"]],
            ["is", "event:props:variant", ["B"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["B"], "metrics" => [1, 1, 50.0]}
             ]
    end

    test "Property breakdown with prop and goal filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, utm_campaign: "campaignA"),
        build(:event,
          user_id: 1,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:pageview, user_id: 2, utm_campaign: "campaignA"),
        build(:event,
          user_id: 2,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{site: site, event_name: "ButtonClick"})

      response =
        query_props(conn, site, "variant",
          filters: [
            ["is", "event:goal", ["ButtonClick"]],
            ["is", "visit:utm_campaign", ["campaignA"]],
            ["is", "event:props:variant", ["A"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["A"], "metrics" => [1, 1, 50.0]}
             ]
    end

    test "Property breakdown with goal and source filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, referrer_source: "Google"),
        build(:event,
          user_id: 1,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:pageview, user_id: 2, referrer_source: "Google"),
        build(:pageview, user_id: 3, referrer_source: "ignore"),
        build(:event,
          user_id: 3,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{site: site, event_name: "ButtonClick"})

      response =
        query_props(conn, site, "variant",
          filters: [
            ["is", "event:goal", ["ButtonClick"]],
            ["is", "visit:source", ["Google"]]
          ],
          metrics: ["visitors", "events", "conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["A"], "metrics" => [1, 1, 50.0]}
             ]
    end

    @tag :ee_only
    test "returns revenue metrics when filtering by a revenue goal", %{conn: conn, site: site} do
      prop_key = "logged_in"

      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["true"],
          revenue_reporting_amount: Decimal.new("12"),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["true"],
          revenue_reporting_amount: Decimal.new("100"),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["false"],
          revenue_reporting_amount: Decimal.new("8"),
          revenue_reporting_currency: "EUR"
        )
      ])

      insert(:goal, %{
        site: site,
        event_name: "Payment",
        currency: :EUR,
        display_name: "PaymentEUR"
      })

      response =
        query_props(conn, site, prop_key,
          filters: [["is", "event:goal", ["PaymentEUR"]]],
          metrics: [
            "visitors",
            "events",
            "conversion_rate",
            "average_revenue",
            "total_revenue"
          ]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["true"],
                 "metrics" => [
                   2,
                   2,
                   66.67,
                   %{
                     "long" => "€56.00",
                     "short" => "€56.0",
                     "value" => 56.0,
                     "currency" => "EUR"
                   },
                   %{
                     "long" => "€112.00",
                     "short" => "€112.0",
                     "value" => 112.0,
                     "currency" => "EUR"
                   }
                 ]
               },
               %{
                 "dimensions" => ["false"],
                 "metrics" => [
                   1,
                   1,
                   33.33,
                   %{"long" => "€8.00", "short" => "€8.0", "value" => 8.0, "currency" => "EUR"},
                   %{"long" => "€8.00", "short" => "€8.0", "value" => 8.0, "currency" => "EUR"}
                 ]
               }
             ]
    end

    @tag :ee_only
    test "returns revenue metrics when filtering by many revenue goals with same currency", %{
      conn: conn,
      site: site
    } do
      prop_key = "logged_in"
      insert(:goal, site: site, event_name: "Payment", currency: "EUR")
      insert(:goal, site: site, event_name: "Payment2", currency: "EUR")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["false"],
          revenue_reporting_amount: Decimal.new("10"),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["true"],
          revenue_reporting_amount: Decimal.new("30"),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "Payment2",
          "meta.key": [prop_key],
          "meta.value": ["true"],
          revenue_reporting_amount: Decimal.new("50"),
          revenue_reporting_currency: "EUR"
        )
      ])

      response =
        query_props(conn, site, prop_key,
          filters: [["is", "event:goal", ["Payment", "Payment2"]]],
          metrics: [
            "visitors",
            "events",
            "conversion_rate",
            "average_revenue",
            "total_revenue"
          ]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["true"],
                 "metrics" => [
                   2,
                   2,
                   66.67,
                   %{
                     "long" => "€40.00",
                     "short" => "€40.0",
                     "value" => 40.0,
                     "currency" => "EUR"
                   },
                   %{"long" => "€80.00", "short" => "€80.0", "value" => 80.0, "currency" => "EUR"}
                 ]
               },
               %{
                 "dimensions" => ["false"],
                 "metrics" => [
                   1,
                   1,
                   33.33,
                   %{
                     "long" => "€10.00",
                     "short" => "€10.0",
                     "value" => 10.0,
                     "currency" => "EUR"
                   },
                   %{"long" => "€10.00", "short" => "€10.0", "value" => 10.0, "currency" => "EUR"}
                 ]
               }
             ]
    end

    @tag :ee_only
    test "does not return revenue metrics when filtering by many revenue goals with different currencies",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")
      insert(:goal, site: site, event_name: "AddToCart", currency: "EUR")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["false"],
          revenue_reporting_amount: Decimal.new("10"),
          revenue_reporting_currency: "EUR"
        )
      ])

      response =
        query_props(conn, site, "whatever-prop",
          filters: [["is", "event:goal", ["Payment", "AddToCart"]]],
          metrics: [
            "visitors",
            "events",
            "conversion_rate",
            "average_revenue",
            "total_revenue"
          ]
        )

      refute "average_revenue" in response["query"]["metrics"]
      refute "total_revenue" in response["query"]["metrics"]
    end
  end

  describe "GET /api/stats/:domain/custom-prop-values/:prop_key - other filters" do
    setup [:create_user, :log_in, :create_site]

    test "returns prop-breakdown with a page filter", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, pathname: "/sipsik", "meta.key": [prop_key], "meta.value": ["Sipsik"])
      ])

      response =
        query_props(conn, site, prop_key, filters: [["is", "event:page", ["/sipsik"]]])

      assert response["results"] == [
               %{"dimensions" => ["Sipsik"], "metrics" => [1, 1, 100.0]}
             ]
    end

    test "returns prop-breakdown with a session-level filter", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview,
          browser: "Chrome",
          "meta.key": [prop_key],
          "meta.value": ["Sipsik"]
        )
      ])

      response =
        query_props(conn, site, prop_key, filters: [["is", "visit:browser", ["Chrome"]]])

      assert response["results"] == [
               %{"dimensions" => ["Sipsik"], "metrics" => [1, 1, 100.0]}
             ]
    end

    test "returns prop-breakdown with a prop_value filter", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Sipsik"])
      ])

      response =
        query_props(conn, site, prop_key,
          filters: [["is", "event:props:parim_s6ber", ["Sipsik"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Sipsik"], "metrics" => [1, 1, 100.0]}
             ]
    end

    test "returns prop-breakdown with a prop_value is_not (none) filter", %{
      conn: conn,
      site: site
    } do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Sipsik"]),
        build(:pageview)
      ])

      response =
        query_props(conn, site, prop_key,
          filters: [["is_not", "event:props:parim_s6ber", ["(none)"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["K2sna Kalle"], "metrics" => [2, 2, 66.67]},
               %{"dimensions" => ["Sipsik"], "metrics" => [1, 1, 33.33]}
             ]
    end

    test "returns prop-breakdown with a prop_value matching filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, "meta.key": ["key"], "meta.value": ["foo"]),
        build(:pageview, "meta.key": ["key"], "meta.value": ["bar"]),
        build(:pageview, "meta.key": ["key"], "meta.value": ["bar"]),
        build(:pageview, "meta.key": ["key"], "meta.value": ["foobar"]),
        build(:pageview)
      ])

      response =
        query_props(conn, site, "key", filters: [["contains", "event:props:key", ["bar"]]])

      assert response["results"] == [
               %{"dimensions" => ["bar"], "metrics" => [2, 2, 66.67]},
               %{"dimensions" => ["foobar"], "metrics" => [1, 1, 33.33]}
             ]
    end

    test "returns prop-breakdown with multiple matching custom property filters", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, "meta.key": ["key", "other"], "meta.value": ["foo", "1"]),
        build(:pageview, "meta.key": ["key", "other"], "meta.value": ["bar", "1"]),
        build(:pageview, "meta.key": ["key", "other"], "meta.value": ["bar", "2"]),
        build(:pageview, "meta.key": ["key"], "meta.value": ["bar"]),
        build(:pageview, "meta.key": ["key", "other"], "meta.value": ["foobar", "1"]),
        build(:pageview, "meta.key": ["key", "other"], "meta.value": ["foobar", "3"]),
        build(:pageview)
      ])

      response =
        query_props(conn, site, "key",
          filters: [
            ["contains", "event:props:key", ["bar"]],
            ["is", "event:props:other", ["1"]]
          ]
        )

      assert response["results"] == [
               %{"dimensions" => ["bar"], "metrics" => [1, 1, 50.0]},
               %{"dimensions" => ["foobar"], "metrics" => [1, 1, 50.0]}
             ]
    end
  end

  describe "GET /api/stats/:domain/custom-prop-values/:prop_key - for a Growth subscription" do
    setup [:create_user, :log_in, :create_site]

    setup %{user: user} do
      subscribe_to_growth_plan(user)
      :ok
    end

    for special_prop <- Plausible.Props.internal_keys() do
      test "returns breakdown for the internally used #{special_prop} prop key", %{
        site: site,
        conn: conn
      } do
        populate_stats(site, [
          build(:pageview,
            "meta.key": [unquote(special_prop)],
            "meta.value": ["some_value"]
          )
        ])

        response = query_props(conn, site, unquote(special_prop))

        assert [
                 %{
                   "dimensions" => ["some_value"],
                   "metrics" => [1, 1, 100.0]
                 }
               ] = response["results"]
      end
    end

    test "returns 400 for a non-internal prop key when on a Growth plan", %{
      conn: conn,
      site: site
    } do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/stats/#{site.domain}/query",
          Jason.encode!(%{
            "dimensions" => ["event:props:prop"],
            "date_range" => "day",
            "metrics" => ["visitors", "events", "percentage"]
          })
        )

      assert json_response(conn, 400) == %{
               "error" =>
                 "The owner of this site does not have access to the custom properties feature."
             }
    end
  end

  describe "with imported data" do
    setup [:create_user, :log_in, :create_site]

    test "gracefully ignores unsupported WP Search Queries goal for imported data", %{
      conn: conn,
      site: site
    } do
      insert(:goal, event_name: "WP Search Queries", site: site)
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:event,
          name: "WP Search Queries",
          "meta.key": ["search_query", "result_count"],
          "meta.value": ["some phrase", "12"]
        ),
        build(:imported_custom_events,
          name: "view_search_results",
          visitors: 100,
          events: 200
        ),
        build(:imported_visitors, visitors: 9)
      ])

      response =
        query_props(conn, site, "search_query",
          filters: [["is", "event:goal", ["WP Search Queries"]]],
          metrics: ["visitors", "events", "conversion_rate"],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["some phrase"], "metrics" => [1, 1, 100.0]}
             ]
    end

    for event_name <- Plausible.Event.SystemEvents.events_with_path_prop() do
      test "returns path breakdown for #{event_name} goal", %{conn: conn, site: site} do
        insert(:goal, event_name: unquote(event_name), site: site)
        site_import = insert(:site_import, site: site)

        populate_stats(site, site_import.id, [
          build(:event,
            name: unquote(event_name),
            "meta.key": ["path"],
            "meta.value": ["/some/path/first.bin"]
          ),
          build(:imported_custom_events,
            name: unquote(event_name),
            visitors: 2,
            events: 5,
            path: "/some/path/first.bin"
          ),
          build(:imported_custom_events,
            name: unquote(event_name),
            visitors: 5,
            events: 10,
            path: "/some/path/second.bin"
          ),
          build(:imported_custom_events,
            name: "view_search_results",
            visitors: 100,
            events: 200
          ),
          build(:imported_visitors, visitors: 9)
        ])

        response =
          query_props(conn, site, "path",
            filters: [["is", "event:goal", [unquote(event_name)]]],
            metrics: ["visitors", "events", "conversion_rate"],
            include: %{"imports" => true}
          )

        assert response["results"] == [
                 %{"dimensions" => ["/some/path/second.bin"], "metrics" => [5, 10, 50.0]},
                 %{"dimensions" => ["/some/path/first.bin"], "metrics" => [3, 6, 30.0]}
               ]
      end
    end

    for event_name <- Plausible.Event.SystemEvents.events_with_url_prop() do
      test "returns url breakdown for #{event_name} goal", %{conn: conn, site: site} do
        insert(:goal, event_name: unquote(event_name), site: site)
        site_import = insert(:site_import, site: site)

        populate_stats(site, site_import.id, [
          build(:event,
            name: unquote(event_name),
            "meta.key": ["url"],
            "meta.value": ["https://one.com"]
          ),
          build(:imported_custom_events,
            name: unquote(event_name),
            visitors: 2,
            events: 5,
            link_url: "https://one.com"
          ),
          build(:imported_custom_events,
            name: unquote(event_name),
            visitors: 5,
            events: 10,
            link_url: "https://two.com"
          ),
          build(:imported_custom_events,
            name: "view_search_results",
            visitors: 100,
            events: 200
          ),
          build(:imported_visitors, visitors: 9)
        ])

        response =
          query_props(conn, site, "url",
            filters: [["is", "event:goal", [unquote(event_name)]]],
            metrics: ["visitors", "events", "conversion_rate"],
            include: %{"imports" => true}
          )

        assert response["results"] == [
                 %{"dimensions" => ["https://two.com"], "metrics" => [5, 10, 50.0]},
                 %{"dimensions" => ["https://one.com"], "metrics" => [3, 6, 30.0]}
               ]
      end
    end

    for event_name <- Plausible.Event.SystemEvents.events_with_url_prop() do
      test "returns url breakdown for #{event_name} goal with a url filter", %{
        conn: conn,
        site: site
      } do
        insert(:goal, event_name: unquote(event_name), site: site)
        site_import = insert(:site_import, site: site)

        populate_stats(site, site_import.id, [
          build(:event,
            name: unquote(event_name),
            "meta.key": ["url"],
            "meta.value": ["https://one.com"]
          ),
          build(:imported_custom_events,
            name: unquote(event_name),
            visitors: 2,
            events: 5,
            link_url: "https://one.com"
          ),
          build(:imported_custom_events,
            name: unquote(event_name),
            visitors: 5,
            events: 10,
            link_url: "https://two.com"
          ),
          build(:imported_custom_events,
            name: "view_search_results",
            visitors: 100,
            events: 200
          ),
          build(:imported_visitors, visitors: 9)
        ])

        response =
          query_props(conn, site, "url",
            filters: [
              ["is", "event:goal", [unquote(event_name)]],
              ["is", "event:props:url", ["https://two.com"]]
            ],
            metrics: ["visitors", "events", "conversion_rate"],
            include: %{"imports" => true}
          )

        assert response["results"] == [
                 %{"dimensions" => ["https://two.com"], "metrics" => [5, 10, 50.0]}
               ]
      end
    end
  end
end
