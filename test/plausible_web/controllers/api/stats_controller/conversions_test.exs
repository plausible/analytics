defmodule PlausibleWeb.Api.StatsController.ConversionsTest do
  use PlausibleWeb.ConnCase

  @user_id Enum.random(1000..9999)

  defp query_conversions(conn, site, opts) do
    params = %{
      "dimensions" => Keyword.get(opts, :dimensions, ["event:goal"]),
      "date_range" => Keyword.get(opts, :date_range, "all"),
      "filters" => Keyword.get(opts, :filters, []),
      "metrics" => Keyword.get(opts, :metrics, ["visitors", "events", "conversion_rate"]),
      "include" => Keyword.get(opts, :include, nil),
      "order_by" => Keyword.get(opts, :order_by, nil)
    }

    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  describe "GET /api/stats/:domain/conversions" do
    setup [:create_user, :log_in, :create_site]

    test "returns mixed pageview and custom event goal conversions ordered by count", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event,
          user_id: @user_id,
          name: "Signup",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Signup",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        ),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      response = query_conversions(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["Signup"], "metrics" => [3, 4, 42.86]},
               %{"dimensions" => ["Visit /register"], "metrics" => [2, 2, 28.57]}
             ]
    end

    test "returns page scroll goals ordered by count", %{conn: conn, site: site} do
      populate_stats(site, [
        # user 1: /blog -> /another -> blog/posts/1
        build(:pageview, user_id: 1, pathname: "/blog", timestamp: ~N[2020-01-01 00:00:00]),
        build(:engagement,
          user_id: 1,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:01:00],
          scroll_depth: 20
        ),
        build(:pageview, user_id: 1, pathname: "/another", timestamp: ~N[2020-01-01 00:01:00]),
        build(:engagement,
          user_id: 1,
          pathname: "/another",
          timestamp: ~N[2020-01-01 00:02:00],
          scroll_depth: 100
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/blog/posts/1",
          timestamp: ~N[2020-01-01 00:02:00]
        ),
        build(:engagement,
          user_id: 1,
          pathname: "/blog/posts/1",
          timestamp: ~N[2020-01-01 00:03:00],
          scroll_depth: 55
        ),
        # user 2: /blog -> /blog/posts/1 -> /blog/posts/2
        build(:pageview, user_id: 2, pathname: "/blog", timestamp: ~N[2020-01-01 00:00:00]),
        build(:engagement,
          user_id: 2,
          pathname: "/blog",
          timestamp: ~N[2020-01-01 00:01:00],
          scroll_depth: 60
        ),
        build(:pageview,
          user_id: 2,
          pathname: "/blog/posts/1",
          timestamp: ~N[2020-01-01 00:02:00]
        ),
        build(:engagement,
          user_id: 2,
          pathname: "/blog/posts/1",
          timestamp: ~N[2020-01-01 00:03:00],
          scroll_depth: 100
        ),
        build(:pageview,
          user_id: 2,
          pathname: "/blog/posts/2",
          timestamp: ~N[2020-01-01 00:02:00]
        ),
        build(:engagement,
          user_id: 2,
          pathname: "/blog/posts/2",
          timestamp: ~N[2020-01-01 00:03:00],
          scroll_depth: 100
        )
      ])

      insert(:goal, %{
        site: site,
        page_path: "/blog/**",
        scroll_threshold: 50,
        display_name: "Scroll 50 /blog/**"
      })

      insert(:goal, %{
        site: site,
        page_path: "/blog/posts/1",
        scroll_threshold: 75,
        display_name: "Scroll 75 /blog/posts/1"
      })

      response = query_conversions(conn, site, date_range: ["2020-01-01", "2020-01-01"])

      assert response["results"] == [
               %{"dimensions" => ["Scroll 50 /blog/**"], "metrics" => [2, nil, 100.0]},
               %{"dimensions" => ["Scroll 75 /blog/posts/1"], "metrics" => [1, nil, 50.0]}
             ]
    end

    test "returns conversions when a direct :is filter on event prop", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "true"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount"],
          "meta.value": ["200"]
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["is", "event:props:logged_in", ["true"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Payment"], "metrics" => [1, 2, 33.33]}
             ]
    end

    test "returns conversions when a direct :is_not filter on event prop", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "true"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event, name: "Payment")
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["is_not", "event:props:logged_in", ["true"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Payment"], "metrics" => [2, 2, 66.67]}
             ]
    end

    test "returns conversions when a direct :is (none) filter on event prop", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment"
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount"],
          "meta.value": ["500"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event, name: "Payment")
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["is", "event:props:logged_in", ["(none)"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Payment"], "metrics" => [2, 3, 66.67]}
             ]
    end

    test "returns conversions when a direct :is_not (none) filter on event prop", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "false"]
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["500", "true"]
        ),
        build(:event,
          name: "Payment",
          "meta.key": ["amount", "logged_in"],
          "meta.value": ["100", "false"]
        ),
        build(:event, name: "Payment")
      ])

      insert(:goal, %{site: site, event_name: "Payment"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["is_not", "event:props:logged_in", ["(none)"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Payment"], "metrics" => [2, 3, 66.67]}
             ]
    end

    test "garbage filters result in a 400 response", %{conn: conn, site: site} do
      params = %{
        "date_range" => "all",
        "metrics" => ["visitors", "events", "conversion_rate"],
        "filters" => [
          ["is", "visit:city AND 2*3*8=6*8 AND 'L9sv'!='L9sv%", ["a"]]
        ]
      }

      response =
        conn
        |> post("/api/stats/#{site.domain}/query", params)
        |> json_response(400)

      assert response["error"] =~ "filter"
    end

    test "filtering by session attribute and multiple goals", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          user_id: @user_id,
          name: "Payment",
          browser: "Firefox"
        ),
        build(:event,
          user_id: @user_id,
          name: "Payment",
          browser: "Firefox"
        ),
        build(:event,
          name: "Payment",
          browser: "Chrome"
        ),
        build(:event, name: "Payment"),
        build(:pageview, browser: "Firefox", pathname: "/"),
        build(:pageview, browser: "Firefox", pathname: "/register")
      ])

      insert(:goal, %{site: site, event_name: "Payment"})
      insert(:goal, %{site: site, page_path: "/register"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["is", "visit:browser", ["Firefox"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Payment"], "metrics" => [1, 2, 33.33]},
               %{"dimensions" => ["Visit /register"], "metrics" => [1, 1, 33.33]}
             ]
    end

    @tag :ee_only
    test "returns formatted average and total values for a conversion with revenue value", %{
      conn: conn,
      site: site
    } do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("200100300.123"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("300100400.123"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("0"),
          revenue_reporting_currency: "USD"
        ),
        build(:event, name: "Payment", revenue_reporting_amount: nil),
        build(:event, name: "Payment", revenue_reporting_amount: nil)
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :EUR})

      response =
        query_conversions(conn, site,
          date_range: "day",
          metrics: ["visitors", "events", "conversion_rate", "average_revenue", "total_revenue"],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["Payment"],
                 "metrics" => [
                   5,
                   5,
                   100.0,
                   %{
                     "short" => "€166.7M",
                     "long" => "€166,733,566.75",
                     "value" => 166_733_566.748,
                     "currency" => "EUR"
                   },
                   %{
                     "short" => "€500.2M",
                     "long" => "€500,200,700.25",
                     "value" => 500_200_700.246,
                     "currency" => "EUR"
                   }
                 ]
               }
             ]
    end

    @tag :ee_only
    test "returns revenue goals as custom events if the plan doesn't cover the feature", %{
      conn: conn,
      site: site,
      user: user
    } do
      user
      |> team_of()
      |> Plausible.Teams.Team.end_trial()
      |> Plausible.Repo.update!()

      populate_stats(site, [
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("200100300.123"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("300100400.123"),
          revenue_reporting_currency: "USD"
        ),
        build(:event,
          name: "Payment",
          revenue_reporting_amount: Decimal.new("0"),
          revenue_reporting_currency: "USD"
        ),
        build(:event, name: "Payment", revenue_reporting_amount: nil),
        build(:event, name: "Payment", revenue_reporting_amount: nil)
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :EUR})

      response =
        query_conversions(conn, site,
          date_range: "day",
          metrics: ["visitors", "events", "conversion_rate", "average_revenue", "total_revenue"]
        )

      assert response["query"]["metrics"] == ["visitors", "events", "conversion_rate"]

      assert response["results"] == [
               %{"dimensions" => ["Payment"], "metrics" => [5, 5, 100.0]}
             ]
    end

    @tag :ee_only
    test "excludes goals with custom props when Props feature is unavailable", %{
      conn: conn,
      site: site,
      user: user
    } do
      user
      |> team_of()
      |> Plausible.Teams.Team.end_trial()
      |> Plausible.Repo.update!()

      populate_stats(site, [
        build(:event, name: "Signup"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup"),
        build(:event, name: "Purchase", "meta.key": ["product"], "meta.value": ["Shirt"])
      ])

      {:ok, _goal_with_props} =
        Plausible.Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"product" => "Shirt"}
        })

      insert(:goal, %{site: site, event_name: "Signup"})

      response = query_conversions(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["Signup"], "metrics" => [3, 3, 75.0]}
             ]
    end

    @tag :ee_only
    test "includes goals with custom props when Props feature is available", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Purchase", "meta.key": ["product"], "meta.value": ["Shirt"]),
        build(:event, name: "Purchase", "meta.key": ["product"], "meta.value": ["Shirt"])
      ])

      {:ok, _goal_with_props} =
        Plausible.Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"product" => "Shirt"}
        })

      response = query_conversions(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["Purchase"], "metrics" => [2, 2, 100.0]}
             ]
    end

    test "returns correct conversion stats for goals with and without custom properties", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Purchase", "meta.key": ["product"], "meta.value": ["Shirt"]),
        build(:event, name: "Purchase", "meta.key": ["product"], "meta.value": ["Shirt"]),
        build(:event, name: "Purchase", "meta.key": ["product"], "meta.value": ["Jacket"])
      ])

      {:ok, _} =
        Plausible.Goals.create(
          site,
          %{
            "event_name" => "Purchase",
            "display_name" => "Purchase - Shirt",
            "custom_props" => %{"product" => "Shirt"}
          }
        )

      {:ok, _} =
        Plausible.Goals.create(
          site,
          %{
            "event_name" => "Purchase",
            "display_name" => "Purchase - Jacket",
            "custom_props" => %{"product" => "Jacket"}
          }
        )

      {:ok, _} =
        Plausible.Goals.create(
          site,
          %{
            "event_name" => "Purchase",
            "display_name" => "Purchase - All"
          }
        )

      response = query_conversions(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["Purchase - All"], "metrics" => [3, 3, 100.0]},
               %{"dimensions" => ["Purchase - Shirt"], "metrics" => [2, 2, 66.67]},
               %{"dimensions" => ["Purchase - Jacket"], "metrics" => [1, 1, 33.33]}
             ]
    end

    @tag :ee_only
    test "handles mixed goals with and without custom props (2)", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Signup"),
        build(:event, name: "Purchase", "meta.key": ["product"], "meta.value": ["Shirt"]),
        build(:event, name: "Purchase", "meta.key": ["product"], "meta.value": ["Shirt"])
      ])

      {:ok, _goal_with_props} =
        Plausible.Goals.create(
          site,
          %{
            "event_name" => "Purchase",
            "custom_props" => %{"product" => "Shirt"}
          }
        )

      insert(:goal, %{site: site, event_name: "Signup"})

      response = query_conversions(conn, site, date_range: "day")

      assert [
               %{"dimensions" => ["Purchase"], "metrics" => [2, 2, 66.67]},
               %{"dimensions" => ["Signup"], "metrics" => [1, 1, 33.33]}
             ] = response["results"]
    end

    @tag :ee_only
    test "returns revenue metrics as nil for non-revenue goals", %{
      conn: conn,
      site: site
    } do
      [
        build(:event,
          name: "Payment",
          pathname: "/checkout",
          revenue_reporting_amount: Decimal.new("10.00"),
          revenue_reporting_currency: "EUR"
        )
      ]
      |> Enum.concat(build_list(2, :event, name: "Signup"))
      |> Enum.concat(build_list(3, :pageview, pathname: "/checkout"))
      |> then(fn events -> populate_stats(site, events) end)

      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, page_path: "/checkout"})
      insert(:goal, %{site: site, event_name: "Payment", currency: :EUR})

      response =
        query_conversions(conn, site,
          date_range: "day",
          metrics: ["visitors", "events", "conversion_rate", "average_revenue", "total_revenue"],
          order_by: [["visitors", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["Payment"],
                 "metrics" => [
                   1,
                   1,
                   16.67,
                   %{
                     "long" => "€10.00",
                     "short" => "€10.0",
                     "value" => 10.0,
                     "currency" => "EUR"
                   },
                   %{
                     "long" => "€10.00",
                     "short" => "€10.0",
                     "value" => 10.0,
                     "currency" => "EUR"
                   }
                 ]
               },
               %{"dimensions" => ["Signup"], "metrics" => [2, 2, 33.33, nil, nil]},
               %{"dimensions" => ["Visit /checkout"], "metrics" => [3, 3, 50.0, nil, nil]}
             ]
    end

    @tag :ee_only
    test "does not return revenue metrics if no revenue goals are returned", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          metrics: [
            "visitors",
            "events",
            "conversion_rate",
            "average_revenue",
            "total_revenue"
          ]
        )

      assert response["query"]["metrics"] == ["visitors", "events", "conversion_rate"]

      assert response["results"] == [
               %{"dimensions" => ["Signup"], "metrics" => [1, 1, 100.0]}
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal filter" do
    setup [:create_user, :log_in, :create_site]

    test "does not consider custom event pathname as a pageview goal completion", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, pathname: "/register", name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      get_with_filters = fn filters ->
        query_conversions(conn, site, date_range: "day", filters: filters)
        |> Map.get("results")
      end

      expected = [
        %{"dimensions" => ["Signup"], "metrics" => [1, 1, 33.33]}
      ]

      # {:is, {:event, event}} filter type
      assert get_with_filters.([["is", "event:goal", ["Signup"]]]) == expected

      # {:member, clauses} filter type
      assert get_with_filters.([["is", "event:goal", ["Signup", "Whatever"]]]) == expected

      # {:matches_member, clauses} filter type
      assert get_with_filters.([["is", "event:goal", ["Signup", "Visit /whatever*"]]]) == expected
    end

    test "does not return custom events with the filtered pageview goal pathname", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, pathname: "/register", name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Visit /register"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Visit /register"], "metrics" => [1, 1, 33.33]}
             ]
    end

    test "can filter by multiple mixed goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, event_name: "Signup"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Signup", "Visit /register"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Signup"], "metrics" => [2, 2, 33.33]},
               %{"dimensions" => ["Visit /register"], "metrics" => [1, 1, 16.67]}
             ]
    end

    test "can combine wildcard and no wildcard in matches_member", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:pageview, pathname: "/billing/upgrade")
      ])

      insert(:goal, %{site: site, page_path: "/blog/**"})
      insert(:goal, %{site: site, page_path: "/billing/upgrade"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Visit /blog/**", "Visit /billing/upgrade"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Visit /blog/**"], "metrics" => [2, 2, 66.67]},
               %{"dimensions" => ["Visit /billing/upgrade"], "metrics" => [1, 1, 33.33]}
             ]
    end

    test "can filter by matches_member filter type on goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:event, name: "CTA"),
        build(:event, name: "Signup")
      ])

      insert(:goal, %{site: site, page_path: "/blog**"})
      insert(:goal, %{site: site, event_name: "CTA"})
      insert(:goal, %{site: site, event_name: "Signup"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Signup", "Visit /blog**"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Visit /blog**"], "metrics" => [2, 2, 33.33]},
               %{"dimensions" => ["Signup"], "metrics" => [1, 1, 16.67]}
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal and prop=(none) filter" do
    setup [:create_user, :log_in, :create_site]

    test "returns only the conversion that is filtered for", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/", user_id: 1),
        build(:pageview, pathname: "/", user_id: 2),
        build(:event, name: "Signup", user_id: 1, "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event, name: "Signup", user_id: 2)
      ])

      insert(:goal, %{site: site, event_name: "Signup"})

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [
            ["is", "event:goal", ["Signup"]],
            ["is", "event:props:variant", ["(none)"]]
          ]
        )

      assert response["results"] == [
               %{"dimensions" => ["Signup"], "metrics" => [1, 1, 50.0]}
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with glob goals" do
    setup [:create_user, :log_in, :create_site]

    test "returns correct and sorted glob goal counts", %{conn: conn, site: site} do
      insert(:goal, %{site: site, page_path: "/register"})
      insert(:goal, %{site: site, page_path: "/reg*"})
      insert(:goal, %{site: site, page_path: "/*/register"})
      insert(:goal, %{site: site, page_path: "/billing*/success"})
      insert(:goal, %{site: site, page_path: "/signup"})
      insert(:goal, %{site: site, page_path: "/signup/*"})
      insert(:goal, %{site: site, page_path: "/*"})

      populate_stats(site, [
        build(:pageview,
          pathname: "/hum",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/register",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          pathname: "/reg",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          user_id: @user_id,
          pathname: "/reg123",
          timestamp: ~N[2019-07-01 23:10:00]
        ),
        build(:pageview,
          pathname: "/billing/success",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/billing/upgrade/success",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/signup/new",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/signup/new/2",
          timestamp: ~N[2019-07-01 23:00:00]
        ),
        build(:pageview,
          pathname: "/signup/new/3",
          timestamp: ~N[2019-07-01 23:00:00]
        )
      ])

      response =
        query_conversions(conn, site,
          date_range: ["2019-07-01", "2019-07-01"],
          order_by: [["visitors", "desc"], ["events", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Visit /*"], "metrics" => [8, 9, 100.0]},
               %{"dimensions" => ["Visit /signup/*"], "metrics" => [3, 3, 37.5]},
               %{"dimensions" => ["Visit /billing*/success"], "metrics" => [2, 2, 25.0]},
               %{"dimensions" => ["Visit /reg*"], "metrics" => [2, 3, 25.0]},
               %{"dimensions" => ["Visit /register"], "metrics" => [1, 1, 12.5]}
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with imported data" do
    setup [:create_user, :log_in, :create_site]

    test "returns custom event goals and pageview goals", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Purchase")
      insert(:goal, site: site, page_path: "/test")

      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          pathname: "/test"
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:imported_custom_events,
          name: "Purchase",
          visitors: 3,
          events: 5,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/test",
          visitors: 2,
          pageviews: 2,
          date: ~D[2021-01-01]
        ),
        build(:imported_visitors, visitors: 5, date: ~D[2021-01-01])
      ])

      response =
        query_conversions(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          include: %{"imports" => true}
        )

      assert [
               %{"dimensions" => ["Purchase"], "metrics" => [5, 7, 62.5]},
               %{"dimensions" => ["Visit /test"], "metrics" => [3, 3, 37.5]}
             ] = response["results"]
    end

    test "returns only custom event goals with a custom event goal filter", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Purchase")
      insert(:goal, site: site, event_name: "Activation")
      insert(:goal, site: site, page_path: "/test")

      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          pathname: "/test"
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:imported_custom_events,
          name: "Purchase",
          visitors: 3,
          events: 5,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/test",
          visitors: 2,
          pageviews: 2,
          date: ~D[2021-01-01]
        ),
        build(:imported_visitors, visitors: 5, date: ~D[2021-01-01])
      ])

      response =
        query_conversions(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:goal", ["Purchase"]]],
          include: %{"imports" => true}
        )

      assert [
               %{"dimensions" => ["Purchase"], "metrics" => [5, 7, 62.5]}
             ] = response["results"]
    end

    test "returns custom event goals with more than one option in goal filter", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Purchase")
      insert(:goal, site: site, event_name: "Activation")
      insert(:goal, site: site, page_path: "/test")

      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          pathname: "/test"
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Activation",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:imported_custom_events,
          name: "Purchase",
          visitors: 3,
          events: 5,
          date: ~D[2021-01-01]
        ),
        build(:imported_custom_events,
          name: "Activation",
          visitors: 2,
          events: 4,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/test",
          visitors: 2,
          pageviews: 2,
          date: ~D[2021-01-01]
        ),
        build(:imported_visitors, visitors: 5, date: ~D[2021-01-01])
      ])

      response =
        query_conversions(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:goal", ["Purchase", "Activation"]]],
          include: %{"imports" => true}
        )

      assert [
               %{"dimensions" => ["Purchase"], "metrics" => [5, 7, 55.56]},
               %{"dimensions" => ["Activation"], "metrics" => [3, 5, 33.33]}
             ] = response["results"]
    end

    test "returns only pageview goals with a pageview goal filter", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Purchase")
      insert(:goal, site: site, event_name: "Activation")
      insert(:goal, site: site, page_path: "/test")

      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          pathname: "/test"
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:imported_custom_events,
          name: "Purchase",
          visitors: 3,
          events: 5,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/test",
          visitors: 2,
          pageviews: 2,
          date: ~D[2021-01-01]
        ),
        build(:imported_visitors, visitors: 5, date: ~D[2021-01-01])
      ])

      response =
        query_conversions(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:goal", ["Visit /test"]]],
          include: %{"imports" => true}
        )

      assert [
               %{"dimensions" => ["Visit /test"], "metrics" => [3, 3, 37.5]}
             ] = response["results"]
    end

    test "returns pageview goals with more than one option in pageview goal filter", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Purchase")
      insert(:goal, site: site, event_name: "Activation")
      insert(:goal, site: site, page_path: "/test")
      insert(:goal, site: site, page_path: "/blog")

      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          pathname: "/test"
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 00:00:01],
          pathname: "/blog"
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:imported_custom_events,
          name: "Purchase",
          visitors: 3,
          events: 5,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/test",
          visitors: 2,
          pageviews: 2,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/blog",
          visitors: 1,
          pageviews: 1,
          date: ~D[2021-01-01]
        ),
        build(:imported_visitors, visitors: 5, date: ~D[2021-01-01])
      ])

      response =
        query_conversions(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:goal", ["Visit /test", "Visit /blog"]]],
          include: %{"imports" => true}
        )

      assert [
               %{"dimensions" => ["Visit /test"], "metrics" => [3, 3, 33.33]},
               %{"dimensions" => ["Visit /blog"], "metrics" => [2, 2, 22.22]}
             ] = response["results"]
    end

    test "returns pageview goals with a page filter", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, page_path: "/blog/two")
      insert(:goal, site: site, page_path: "/blog/thr**")
      insert(:goal, site: site, page_path: "/blog/*")

      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:imported_pages, page: "/", visitors: 1, pageviews: 1, date: ~D[2021-01-01]),
        build(:imported_pages,
          page: "/blog/one",
          visitors: 2,
          pageviews: 2,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/blog/two",
          visitors: 3,
          pageviews: 3,
          date: ~D[2021-01-01]
        ),
        build(:imported_pages,
          page: "/blog/three",
          visitors: 4,
          pageviews: 4,
          date: ~D[2021-01-01]
        ),
        build(:imported_visitors, visitors: 10, date: ~D[2021-01-01])
      ])

      response =
        query_conversions(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          filters: [["is", "event:page", ["/blog/one", "/blog/two"]]],
          include: %{"imports" => true}
        )

      assert [
               %{"dimensions" => ["Visit /blog/*"], "metrics" => [5, 5, 100.0]},
               %{"dimensions" => ["Visit /blog/two"], "metrics" => [3, 3, 60.0]}
             ] = response["results"]
    end

    test "calculates conversion_rate for goals with glob pattern with imported data", %{
      conn: conn,
      site: site
    } do
      site_import =
        insert(:site_import,
          site: site,
          start_date: ~D[2005-01-01],
          end_date: Date.utc_today(),
          source: :universal_analytics
        )

      populate_stats(site, site_import.id, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/another"),
        build(:pageview, pathname: "/blog/post-1"),
        build(:pageview, pathname: "/blog/post-2"),
        build(:imported_pages, page: "/blog/post-1"),
        build(:imported_visitors)
      ])

      insert(:goal, %{site: site, page_path: "/blog**"})

      response = query_conversions(conn, site, date_range: "day", include: %{"imports" => true})

      assert response["meta"]["imports_included"]

      assert response["results"] == [
               %{"dimensions" => ["Visit /blog**"], "metrics" => [3, 3, 60.0]}
             ]
    end

    test "filtering with goal contains filter", %{
      conn: conn,
      site: site
    } do
      site_import =
        insert(:site_import,
          site: site,
          start_date: ~D[2005-01-01],
          end_date: Date.utc_today(),
          source: :universal_analytics
        )

      insert(:goal, site: site, event_name: "Onboarding: Step 1")
      insert(:goal, site: site, event_name: "Onboarding: Step 2")
      insert(:goal, site: site, event_name: "Unrelated")

      populate_stats(site, site_import.id, [
        build(:event, name: "Onboarding: Step 1"),
        build(:event, name: "Onboarding: Step 1"),
        build(:event, name: "Onboarding: Step 2"),
        build(:event, name: "Unrelated"),
        build(:imported_custom_events, name: "Onboarding: Step 1", visitors: 2, events: 2),
        build(:imported_custom_events, name: "Onboarding: Step 2"),
        build(:imported_custom_events, name: "Unrelated"),
        build(:imported_visitors, visitors: 4)
      ])

      response =
        query_conversions(conn, site,
          date_range: "day",
          filters: [["contains", "event:goal", ["Onboarding"]]],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["Onboarding: Step 1"], "metrics" => [4, 4, 50.0]},
               %{"dimensions" => ["Onboarding: Step 2"], "metrics" => [2, 2, 25.0]}
             ]
    end
  end
end
