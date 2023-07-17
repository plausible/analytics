defmodule PlausibleWeb.Api.StatsController.PropBreakdownTest do
  use PlausibleWeb.ConnCase

  # credo:disable-for-next-line
  # TODO: Remove this file once the new Properties feature is live.

  # All tests in this file were copied into `custom_prop_breakdown_test.exs`
  # testing the exact same features for the new
  # `/api/stats/:domain/custom-prop-values/:key` route.

  describe "GET /api/stats/:domain/property/:key" do
    setup [:create_user, :log_in, :create_new_site]

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
      filters = Jason.encode!(%{goal: "Signup"})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 2,
                 "name" => "B",
                 "total_conversions" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "unique_conversions" => 1,
                 "name" => "A",
                 "total_conversions" => 1,
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
      filters = Jason.encode!(%{goal: "Signup"})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 2,
                 "name" => "(none)",
                 "total_conversions" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "unique_conversions" => 1,
                 "name" => "A",
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "0"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "0",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "(none)",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!0"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "20",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "(none)",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "0",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "0|1"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "1",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "0",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "1|(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "1",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "(none)",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!0|0.01"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "20",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
                 "conversion_rate" => 40.0
               },
               %{
                 "name" => "(none)",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!0|(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "20",
                 "unique_conversions" => 2,
                 "total_conversions" => 2,
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
      filters = Jason.encode!(%{goal: "Visit /register"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/variant?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 2,
                 "name" => "A",
                 "total_conversions" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "unique_conversions" => 1,
                 "name" => "(none)",
                 "total_conversions" => 1,
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
      filters = Jason.encode!(%{goal: "Signup", props: %{"variant" => "B"}})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "unique_conversions" => 1,
                 "name" => "B",
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "ButtonClick",
          props: %{variant: "A"},
          utm_campaign: "campaignA"
        })

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "A",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
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
        Jason.encode!(%{
          goal: "ButtonClick",
          source: "Google"
        })

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/property/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "A",
                 "unique_conversions" => 1,
                 "total_conversions" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end
  end
end
