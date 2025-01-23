defmodule PlausibleWeb.Api.StatsController.CustomPropBreakdownTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

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

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "K2sna Kalle",
                 "events" => 2,
                 "percentage" => 50.0
               },
               %{
                 "visitors" => 1,
                 "name" => "Lotte",
                 "events" => 2,
                 "percentage" => 25.0
               },
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 25.0
               }
             ]
    end

    test "ignores imported data when calculating percentage", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:imported_visitors, visitors: 2)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&with_imported=true"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 1,
                 "name" => "K2sna Kalle",
                 "events" => 1,
                 "percentage" => 100.0
               }
             ]

      refute json_response(conn, 200)["warning"]
    end

    test "returns (none) values in the breakdown", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "K2sna Kalle",
                 "events" => 2,
                 "percentage" => 66.7
               },
               %{
                 "visitors" => 1,
                 "name" => "(none)",
                 "events" => 1,
                 "percentage" => 33.3
               }
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

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&limit=2&page=1"
        )

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&limit=2&page=2"
        )

      assert json_response(conn1, 200)["results"] == [
               %{
                 "visitors" => 3,
                 "name" => "Tiit",
                 "events" => 3,
                 "percentage" => 50.0
               },
               %{
                 "visitors" => 2,
                 "name" => "Teet",
                 "events" => 2,
                 "percentage" => 33.3
               }
             ]

      assert json_response(conn2, 200)["results"] == [
               %{
                 "visitors" => 1,
                 "name" => "(none)",
                 "events" => 1,
                 "percentage" => 16.7
               }
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
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "B",
                 "events" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "visitors" => 1,
                 "name" => "A",
                 "events" => 1,
                 "conversion_rate" => 16.7
               }
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
      filters = Jason.encode!([[:is, "event:goal", ["Signup"]]])
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "(none)",
                 "events" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "visitors" => 1,
                 "name" => "A",
                 "events" => 1,
                 "conversion_rate" => 16.7
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Purchase"]],
          [:is, "event:props:cost", ["0"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "0",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Purchase"]],
          [:is, "event:props:cost", ["(none)"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "(none)",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Purchase"]],
          [:is_not, "event:props:cost", ["0"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "20",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "(none)",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 25.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Purchase"]],
          [:is_not, "event:props:cost", ["(none)"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "0",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Purchase"]],
          [:is, "event:props:cost", ["0", "1"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "1",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "0",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 25.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Purchase"]],
          [:is, "event:props:cost", ["1", "(none)"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "1",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "(none)",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 25.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Purchase"]],
          [:is_not, "event:props:cost", ["0", "0.01"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "20",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 40.0
               },
               %{
                 "name" => "(none)",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 20.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Purchase"]],
          [:is_not, "event:props:cost", ["0", "(none)"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "20",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 50.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Visit /register"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/variant?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "A",
                 "events" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "visitors" => 1,
                 "name" => "(none)",
                 "events" => 1,
                 "conversion_rate" => 25.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Signup"]],
          [:is, "event:props:variant", ["B"]]
        ])

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 1,
                 "name" => "B",
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["ButtonClick"]],
          [:is, "visit:utm_campaign", ["campaignA"]],
          [:is, "event:props:variant", ["A"]]
        ])

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "A",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["ButtonClick"]],
          [:is, "visit:source", ["Google"]]
        ])

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "name" => "A",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["PaymentEUR"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "true",
                 "events" => 2,
                 "conversion_rate" => 66.7,
                 "total_revenue" => %{
                   "long" => "€112.00",
                   "short" => "€112.0",
                   "value" => 112.00,
                   "currency" => "EUR"
                 },
                 "average_revenue" => %{
                   "long" => "€56.00",
                   "short" => "€56.0",
                   "value" => 56.00,
                   "currency" => "EUR"
                 }
               },
               %{
                 "visitors" => 1,
                 "name" => "false",
                 "events" => 1,
                 "conversion_rate" => 33.3,
                 "total_revenue" => %{
                   "long" => "€8.00",
                   "short" => "€8.0",
                   "value" => 8.00,
                   "currency" => "EUR"
                 },
                 "average_revenue" => %{
                   "long" => "€8.00",
                   "short" => "€8.0",
                   "value" => 8.00,
                   "currency" => "EUR"
                 }
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Payment", "Payment2"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "true",
                 "events" => 2,
                 "conversion_rate" => 66.7,
                 "total_revenue" => %{
                   "long" => "€80.00",
                   "short" => "€80.0",
                   "value" => 80.0,
                   "currency" => "EUR"
                 },
                 "average_revenue" => %{
                   "long" => "€40.00",
                   "short" => "€40.0",
                   "value" => 40.0,
                   "currency" => "EUR"
                 }
               },
               %{
                 "visitors" => 1,
                 "name" => "false",
                 "events" => 1,
                 "conversion_rate" => 33.3,
                 "total_revenue" => %{
                   "long" => "€10.00",
                   "short" => "€10.0",
                   "value" => 10.0,
                   "currency" => "EUR"
                 },
                 "average_revenue" => %{
                   "long" => "€10.00",
                   "short" => "€10.0",
                   "value" => 10.0,
                   "currency" => "EUR"
                 }
               }
             ]
    end

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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["Payment", "AddToCart"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/whatever-prop?period=day&filters=#{filters}"
        )

      returned_metrics =
        json_response(conn, 200)
        |> Map.get("results")
        |> List.first()
        |> Map.keys()

      refute "Average revenue" in returned_metrics
      refute "Total revenue" in returned_metrics
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

      filters = Jason.encode!([[:is, "event:page", ["/sipsik"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 100.0
               }
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

      filters = Jason.encode!([[:is, "visit:browser", ["Chrome"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 100.0
               }
             ]
    end

    test "returns prop-breakdown with a prop_value filter", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Sipsik"])
      ])

      filters =
        Jason.encode!([
          [:is, "event:props:parim_s6ber", ["Sipsik"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 100.0
               }
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

      filters =
        Jason.encode!([
          [:is_not, "event:props:parim_s6ber", ["(none)"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "K2sna Kalle",
                 "events" => 2,
                 "percentage" => 66.7
               },
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 33.3
               }
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

      filters =
        Jason.encode!([
          [:contains, "event:props:key", ["bar"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/key?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 2,
                 "name" => "bar",
                 "events" => 2,
                 "percentage" => 66.7
               },
               %{
                 "visitors" => 1,
                 "name" => "foobar",
                 "events" => 1,
                 "percentage" => 33.3
               }
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

      filters =
        Jason.encode!([
          [:contains, "event:props:key", ["bar"]],
          [:is, "event:props:other", ["1"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/key?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 1,
                 "name" => "bar",
                 "events" => 1,
                 "percentage" => 50.0
               },
               %{
                 "visitors" => 1,
                 "name" => "foobar",
                 "events" => 1,
                 "percentage" => 50.0
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/custom-prop-values/:prop_key - for a Growth subscription" do
    setup [:create_user, :log_in, :create_site]

    setup %{user: user} do
      subscribe_to_growth_plan(user)
      :ok
    end

    for special_prop <- ["url", "path", "search_query", "form"] do
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

        assert [%{"visitors" => 1, "name" => "some_value"}] =
                 conn
                 |> get(
                   "/api/stats/#{site.domain}/custom-prop-values/#{unquote(special_prop)}?period=day"
                 )
                 |> json_response(200)
                 |> Map.get("results")
      end
    end

    test "returns 402 'upgrade required' for any other prop key", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/custom-prop-values/prop?period=day")

      assert json_response(conn, 402) == %{
               "error" =>
                 "Custom Properties is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["WP Search Queries"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/search_query?period=day&with_imported=true&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 1,
                 "name" => "some phrase",
                 "events" => 1,
                 "conversion_rate" => 100.0
               }
             ]
    end

    test "returns path breakdown for 404 goal", %{conn: conn, site: site} do
      insert(:goal, event_name: "404", site: site)
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:event,
          name: "404",
          "meta.key": ["path"],
          "meta.value": ["/some/path/first.bin"]
        ),
        build(:imported_custom_events,
          name: "404",
          visitors: 2,
          events: 5,
          path: "/some/path/first.bin"
        ),
        build(:imported_custom_events,
          name: "404",
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

      filters =
        Jason.encode!([
          [:is, "event:goal", ["404"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/path?period=day&with_imported=true&filters=#{filters}"
        )

      assert json_response(conn, 200)["results"] == [
               %{
                 "visitors" => 5,
                 "name" => "/some/path/second.bin",
                 "events" => 10,
                 "conversion_rate" => 50.0
               },
               %{
                 "visitors" => 3,
                 "name" => "/some/path/first.bin",
                 "events" => 6,
                 "conversion_rate" => 30.0
               }
             ]
    end

    for goal_name <- ["Outbound Link: Click", "File Download", "Cloaked Link: Click"] do
      test "returns url breakdown for #{goal_name} goal", %{conn: conn, site: site} do
        insert(:goal, event_name: unquote(goal_name), site: site)
        site_import = insert(:site_import, site: site)

        populate_stats(site, site_import.id, [
          build(:event,
            name: unquote(goal_name),
            "meta.key": ["url"],
            "meta.value": ["https://one.com"]
          ),
          build(:imported_custom_events,
            name: unquote(goal_name),
            visitors: 2,
            events: 5,
            link_url: "https://one.com"
          ),
          build(:imported_custom_events,
            name: unquote(goal_name),
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

        filters =
          Jason.encode!([
            [:is, "event:goal", [unquote(goal_name)]]
          ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/custom-prop-values/url?period=day&with_imported=true&filters=#{filters}"
          )

        assert json_response(conn, 200)["results"] == [
                 %{
                   "visitors" => 5,
                   "name" => "https://two.com",
                   "events" => 10,
                   "conversion_rate" => 50.0
                 },
                 %{
                   "visitors" => 3,
                   "name" => "https://one.com",
                   "events" => 6,
                   "conversion_rate" => 30.0
                 }
               ]
      end
    end

    for goal_name <- ["Outbound Link: Click", "File Download", "Cloaked Link: Click"] do
      test "returns url breakdown for #{goal_name} goal with a url filter", %{
        conn: conn,
        site: site
      } do
        insert(:goal, event_name: unquote(goal_name), site: site)
        site_import = insert(:site_import, site: site)

        populate_stats(site, site_import.id, [
          build(:event,
            name: unquote(goal_name),
            "meta.key": ["url"],
            "meta.value": ["https://one.com"]
          ),
          build(:imported_custom_events,
            name: unquote(goal_name),
            visitors: 2,
            events: 5,
            link_url: "https://one.com"
          ),
          build(:imported_custom_events,
            name: unquote(goal_name),
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

        filters =
          Jason.encode!([
            [:is, "event:goal", [unquote(goal_name)]],
            [:is, "event:props:url", ["https://two.com"]]
          ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/custom-prop-values/url?period=day&with_imported=true&filters=#{filters}"
          )

        assert json_response(conn, 200)["results"] == [
                 %{
                   "visitors" => 5,
                   "name" => "https://two.com",
                   "events" => 10,
                   "conversion_rate" => 50.0
                 }
               ]
      end
    end
  end
end
