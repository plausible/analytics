defmodule PlausibleWeb.Api.StatsController.FunnelsTest do
  use PlausibleWeb.ConnCase, async: true
  @moduletag :ee_only

  on_ee do
    @user_id Enum.random(1000..9999)
    @other_user_id @user_id + 1

    @build_funnel_with [
      {"page_path", "/blog/announcement"},
      {"event_name", "Signup"},
      {"page_path", "/cart/add/product"},
      {"event_name", "Purchase"}
    ]

    describe "GET /api/stats/funnel - default" do
      setup [:create_user, :log_in, :create_site]

      test "computes funnel for a day", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)

        populate_stats(site, [
          build(:pageview, pathname: "/some/irrelevant", user_id: 9_999_999),
          build(:pageview, pathname: "/blog/announcement", user_id: @user_id),
          build(:pageview, pathname: "/blog/announcement", user_id: @other_user_id),
          build(:event, name: "Signup", user_id: @user_id),
          build(:event, name: "Signup", user_id: @other_user_id),
          build(:pageview, pathname: "/cart/add/product", user_id: @user_id),
          build(:event, name: "Purchase", user_id: @user_id)
        ])

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day")
          |> json_response(200)

        assert %{
                 "name" => "Test funnel",
                 "strict_order" => false,
                 "comparison" => nil,
                 "all_visitors" => 3,
                 "entering_visitors" => 2,
                 "entering_visitors_percentage" => "66.67",
                 "never_entering_visitors" => 1,
                 "never_entering_visitors_percentage" => "33.33",
                 "steps" => [
                   %{
                     "conversion_rate" => "100",
                     "conversion_rate_step" => "0",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Visit /blog/announcement",
                     "visitors" => 2
                   },
                   %{
                     "conversion_rate" => "100",
                     "conversion_rate_step" => "100",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Signup",
                     "visitors" => 2
                   },
                   %{
                     "conversion_rate" => "50",
                     "conversion_rate_step" => "50",
                     "dropoff" => 1,
                     "dropoff_percentage" => "50",
                     "label" => "Visit /cart/add/product",
                     "visitors" => 1
                   },
                   %{
                     "conversion_rate" => "50",
                     "conversion_rate_step" => "100",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Purchase",
                     "visitors" => 1
                   }
                 ]
               } = resp
      end

      test "computes a strict-order funnel for a day", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with, strict_order?: true)

        populate_stats(site, [
          build(:pageview, pathname: "/blog/announcement", user_id: @user_id),
          build(:event, name: "Signup", user_id: @user_id)
        ])

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day")
          |> json_response(200)

        assert %{
                 "name" => "Test funnel",
                 "strict_order" => true,
                 "all_visitors" => 1,
                 "entering_visitors" => 1
               } = resp
      end

      test "404 for unknown funnel", %{site: site, conn: conn} do
        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/122873/?period=day")
          |> json_response(404)

        assert resp == %{"error" => "Funnel not found"}
      end

      test "400 for bad funnel ID", %{site: site, conn: conn} do
        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/foobar/?period=day")
          |> json_response(400)

        assert resp == %{"error" => "There was an error with your request"}
      end

      test "computes all-time funnel with filters", %{conn: conn, user: user} do
        site = new_site(stats_start_date: ~D[2020-01-01], owner: user)
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)

        populate_stats(site, [
          build(:pageview, pathname: "/blog/announcement", user_id: @user_id),
          build(:pageview,
            pathname: "/blog/announcement",
            user_id: @other_user_id,
            timestamp: ~N[2021-01-01 12:00:00],
            utm_medium: "social"
          ),
          build(:event, name: "Signup", user_id: @user_id),
          build(:event,
            name: "Signup",
            user_id: @other_user_id,
            timestamp: ~N[2021-01-01 12:01:00],
            utm_medium: "social"
          ),
          build(:pageview, pathname: "/cart/add/product", user_id: @user_id),
          build(:event, name: "Purchase", user_id: @user_id)
        ])

        filters = Jason.encode!([[:is, "visit:utm_medium", ["social"]]])

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=all&filters=#{filters}")
          |> json_response(200)

        assert %{
                 "name" => "Test funnel",
                 "all_visitors" => 1,
                 "entering_visitors" => 1,
                 "entering_visitors_percentage" => "100",
                 "never_entering_visitors" => 0,
                 "never_entering_visitors_percentage" => "0",
                 "steps" => [
                   %{
                     "conversion_rate" => "100",
                     "conversion_rate_step" => "0",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Visit /blog/announcement",
                     "visitors" => 1
                   },
                   %{
                     "conversion_rate" => "100",
                     "conversion_rate_step" => "100",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Signup",
                     "visitors" => 1
                   },
                   %{
                     "conversion_rate" => "0",
                     "conversion_rate_step" => "0",
                     "dropoff" => 1,
                     "dropoff_percentage" => "100",
                     "label" => "Visit /cart/add/product",
                     "visitors" => 0
                   },
                   %{
                     "conversion_rate" => "0",
                     "conversion_rate_step" => "0",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Purchase",
                     "visitors" => 0
                   }
                 ]
               } = resp
      end

      test "computes an empty funnel", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day")
          |> json_response(200)

        assert %{
                 "name" => "Test funnel",
                 "all_visitors" => 0,
                 "entering_visitors" => 0,
                 "entering_visitors_percentage" => "0",
                 "never_entering_visitors" => 0,
                 "never_entering_visitors_percentage" => "0",
                 "steps" => [
                   %{
                     "conversion_rate" => "0",
                     "conversion_rate_step" => "0",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Visit /blog/announcement",
                     "visitors" => 0
                   },
                   %{
                     "conversion_rate" => "0",
                     "conversion_rate_step" => "0",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Signup",
                     "visitors" => 0
                   },
                   %{
                     "conversion_rate" => "0",
                     "conversion_rate_step" => "0",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Visit /cart/add/product",
                     "visitors" => 0
                   },
                   %{
                     "conversion_rate" => "0",
                     "conversion_rate_step" => "0",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Purchase",
                     "visitors" => 0
                   }
                 ]
               } = resp
      end

      test "returns HTTP 402 when site owner is on a growth plan", %{
        conn: conn,
        user: user,
        site: site
      } do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)
        subscribe_to_growth_plan(user)

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day")
          |> json_response(402)

        assert %{
                 "error" =>
                   "Funnels and user journeys is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
               } == resp
      end
    end

    describe "GET /api/stats/funnel - comparisons" do
      setup [:create_user, :log_in, :create_site]

      @comparison_stats [
        # 2021-01-02: one visitor reaches Signup
        {"/blog/announcement", @user_id, ~N[2021-01-02 12:00:00]},
        {"Signup", @user_id, ~N[2021-01-02 12:01:00]},
        # 2021-01-01: two visitors enter, one reaches Signup
        {"/blog/announcement", @user_id, ~N[2021-01-01 12:00:00]},
        {"/blog/announcement", @other_user_id, ~N[2021-01-01 13:00:00]},
        {"Signup", @other_user_id, ~N[2021-01-01 13:01:00]}
      ]

      defp populate_comparison_stats(site) do
        populate_stats(
          site,
          Enum.map(@comparison_stats, fn
            {"/" <> _ = pathname, user_id, timestamp} ->
              build(:pageview, pathname: pathname, user_id: user_id, timestamp: timestamp)

            {name, user_id, timestamp} ->
              build(:event, name: name, user_id: user_id, timestamp: timestamp)
          end)
        )
      end

      test "gives no comparison without a comparison param", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)
        populate_comparison_stats(site)

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&date=2021-01-02")
          |> json_response(200)

        assert resp["comparison"] == nil
        assert resp["comparison_date_range"] == nil
        assert resp["date_range"] == ["2021-01-02", "2021-01-02"]
      end

      test "compares against the previous period", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)
        populate_comparison_stats(site)

        resp =
          conn
          |> get(
            "/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&date=2021-01-02&comparison=previous_period"
          )
          |> json_response(200)

        assert %{
                 "all_visitors" => 1,
                 "entering_visitors" => 1,
                 "date_range" => ["2021-01-02", "2021-01-02"],
                 "comparison_date_range" => ["2021-01-01", "2021-01-01"],
                 "steps" => [
                   %{"label" => "Visit /blog/announcement", "visitors" => 1},
                   %{"label" => "Signup", "visitors" => 1, "conversion_rate" => "100"},
                   %{"label" => "Visit /cart/add/product", "visitors" => 0},
                   %{"label" => "Purchase", "visitors" => 0}
                 ],
                 "comparison" => %{
                   "all_visitors" => 2,
                   "entering_visitors" => 2,
                   "entering_visitors_percentage" => "100",
                   "never_entering_visitors" => 0,
                   "never_entering_visitors_percentage" => "0",
                   "steps" => [
                     %{
                       "label" => "Visit /blog/announcement",
                       "visitors" => 2,
                       "conversion_rate" => "100"
                     },
                     %{
                       "label" => "Signup",
                       "visitors" => 1,
                       "conversion_rate" => "50",
                       "dropoff" => 1,
                       "dropoff_percentage" => "50"
                     },
                     %{"label" => "Visit /cart/add/product", "visitors" => 0},
                     %{"label" => "Purchase", "visitors" => 0}
                   ]
                 }
               } = resp
      end

      test "compares against a custom period", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)
        populate_comparison_stats(site)

        resp =
          conn
          |> get(
            "/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&date=2021-01-02&comparison=custom&compare_from=2021-01-01&compare_to=2021-01-01"
          )
          |> json_response(200)

        assert %{
                 "date_range" => ["2021-01-02", "2021-01-02"],
                 "comparison_date_range" => ["2021-01-01", "2021-01-01"],
                 "comparison" => %{
                   "all_visitors" => 2,
                   "entering_visitors" => 2,
                   "steps" => [
                     %{"visitors" => 2},
                     %{"visitors" => 1},
                     %{"visitors" => 0},
                     %{"visitors" => 0}
                   ]
                 }
               } = resp
      end
    end

    describe "GET /api/stats/funnel - disallowed filters" do
      setup [:create_user, :log_in, :create_site]

      test "event:page", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)

        filters = Jason.encode!([[:is, "event:page", ["/pageA"]]])

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&filters=#{filters}")
          |> json_response(400)

        assert resp == %{
                 "error" => "Funnels aren't available when the dashboard is filtered by pages",
                 "level" => "normal"
               }
      end

      test "event:goal", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)

        filters =
          Jason.encode!([[:is, "event:goal", ["Signup"]], [:is, "event:page", ["/pageA"]]])

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&filters=#{filters}")
          |> json_response(400)

        assert resp == %{
                 "error" => "Funnels aren't available when the dashboard is filtered by goals",
                 "level" => "normal"
               }
      end

      test "period: realtime", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=realtime")
          |> json_response(400)

        assert resp == %{
                 "error" =>
                   "Funnels aren't available when the dashboard is filtered by realtime period",
                 "level" => "normal"
               }
      end
    end

    describe "GET /api/stats/funnel - page scroll goals" do
      setup [:create_user, :log_in, :create_site]

      test "computes a funnel with page scroll goals", %{conn: conn, site: site} do
        goals = [
          insert(:goal, site: site, event_name: "Onboarding Start"),
          insert(:goal,
            site: site,
            page_path: "/onboard",
            scroll_threshold: 25,
            display_name: "Scroll 25% on /onboard"
          ),
          insert(:goal,
            site: site,
            page_path: "/onboard",
            scroll_threshold: 50,
            display_name: "Scroll 50% on /onboard"
          ),
          insert(:goal,
            site: site,
            page_path: "/onboard",
            scroll_threshold: 75,
            display_name: "Scroll 75% on /onboard"
          ),
          insert(:goal, site: site, page_path: "/onboard-completed")
        ]

        {:ok, funnel} =
          Plausible.Funnels.create(site, "Onboarding", Enum.map(goals, &%{"goal_id" => &1.id}))

        populate_stats(site, [
          # user 1 - completes the whole funnel
          build(:event, user_id: 1, name: "Onboarding Start", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, user_id: 1, pathname: "/onboard", timestamp: ~N[2021-01-01 00:00:10]),
          build(:engagement,
            user_id: 1,
            pathname: "/onboard",
            scroll_depth: 80,
            timestamp: ~N[2021-01-01 00:00:20]
          ),
          build(:pageview,
            user_id: 1,
            pathname: "/onboard-completed",
            timestamp: ~N[2021-01-01 00:00:30]
          ),
          # user 2 - drops off after scrolling 25% on /onboard
          build(:event, user_id: 2, name: "Onboarding Start", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, user_id: 2, pathname: "/onboard", timestamp: ~N[2021-01-01 00:00:10]),
          build(:engagement,
            user_id: 2,
            pathname: "/onboard",
            scroll_depth: 25,
            timestamp: ~N[2021-01-01 00:00:20]
          )
        ])

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&date=2021-01-01")
          |> json_response(200)

        assert %{
                 "all_visitors" => 2,
                 "entering_visitors" => 2,
                 "entering_visitors_percentage" => "100",
                 "name" => "Onboarding",
                 "never_entering_visitors" => 0,
                 "never_entering_visitors_percentage" => "0",
                 "steps" => [
                   %{
                     "conversion_rate" => "100",
                     "conversion_rate_step" => "0",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Onboarding Start",
                     "visitors" => 2
                   },
                   %{
                     "conversion_rate" => "100",
                     "conversion_rate_step" => "100",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Scroll 25% on /onboard",
                     "visitors" => 2
                   },
                   %{
                     "conversion_rate" => "50",
                     "conversion_rate_step" => "50",
                     "dropoff" => 1,
                     "dropoff_percentage" => "50",
                     "label" => "Scroll 50% on /onboard",
                     "visitors" => 1
                   },
                   %{
                     "conversion_rate" => "50",
                     "conversion_rate_step" => "100",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Scroll 75% on /onboard",
                     "visitors" => 1
                   },
                   %{
                     "conversion_rate" => "50",
                     "conversion_rate_step" => "100",
                     "dropoff" => 0,
                     "dropoff_percentage" => "0",
                     "label" => "Visit /onboard-completed",
                     "visitors" => 1
                   }
                 ]
               } = resp
      end
    end

    describe "GET /api/stats/funnel - revenue" do
      setup [:create_user, :log_in, :create_site]

      test "reports revenue on the step whose goal is a revenue goal", %{
        conn: conn,
        site: site
      } do
        {:ok, funnel} = setup_checkout_funnel(site)

        populate_stats(site, [
          build(:pageview, pathname: "/checkout", user_id: @user_id),
          build(:pageview, pathname: "/checkout", user_id: @other_user_id),
          purchase(@user_id, "100"),
          purchase(@other_user_id, "300")
        ])

        assert [checkout_step, purchase_step] = funnel_steps(conn, site, funnel)

        refute Map.has_key?(checkout_step, "revenue")
        refute Map.has_key?(checkout_step, "revenue_per_visitor")

        assert %{
                 "visitors" => 2,
                 "revenue" => %{
                   "short" => "$400.0",
                   "long" => "$400.00",
                   "value" => 400.0,
                   "currency" => "USD"
                 },
                 "revenue_per_visitor" => %{
                   "short" => "$200.0",
                   "long" => "$200.00",
                   "value" => 200.0,
                   "currency" => "USD"
                 }
               } = purchase_step
      end

      test "divides the revenue by visitors, not by orders", %{conn: conn, site: site} do
        {:ok, funnel} = setup_checkout_funnel(site)

        populate_stats(site, [
          build(:pageview, pathname: "/checkout", user_id: @user_id),
          purchase(@user_id, "100"),
          purchase(@user_id, "300")
        ])

        assert [_checkout_step, purchase_step] = funnel_steps(conn, site, funnel)

        assert %{
                 "visitors" => 1,
                 "revenue" => %{"long" => "$400.00"},
                 "revenue_per_visitor" => %{"long" => "$400.00"}
               } = purchase_step
      end

      test "counts the revenue of a mid-funnel step for everyone who reached it", %{
        conn: conn,
        site: site
      } do
        {:ok, [checkout, thanks]} =
          setup_goals(site, [{"page_path", "/checkout"}, {"page_path", "/thanks"}])

        purchase = insert(:goal, site: site, event_name: "Purchase", currency: "USD")
        {:ok, funnel} = funnel_with_goals(site, [checkout, purchase, thanks])

        populate_stats(site, [
          build(:pageview,
            pathname: "/checkout",
            user_id: @user_id,
            timestamp: ~N[2021-01-01 12:00:00]
          ),
          purchase(@user_id, "100", timestamp: ~N[2021-01-01 12:01:00]),
          build(:pageview,
            pathname: "/thanks",
            user_id: @user_id,
            timestamp: ~N[2021-01-01 12:02:00]
          ),
          build(:pageview,
            pathname: "/checkout",
            user_id: @other_user_id,
            timestamp: ~N[2021-01-01 13:00:00]
          ),
          purchase(@other_user_id, "300", timestamp: ~N[2021-01-01 13:01:00])
        ])

        assert [_checkout_step, purchase_step, thanks_step] =
                 funnel_steps(conn, site, funnel, "period=day&date=2021-01-01")

        assert %{
                 "visitors" => 2,
                 "revenue" => %{"long" => "$400.00"},
                 "revenue_per_visitor" => %{"long" => "$200.00"}
               } = purchase_step

        refute Map.has_key?(thanks_step, "revenue")
      end

      test "reports revenue for the comparison period", %{conn: conn, site: site} do
        {:ok, funnel} = setup_checkout_funnel(site)

        populate_stats(site, [
          build(:pageview,
            pathname: "/checkout",
            user_id: @user_id,
            timestamp: ~N[2021-01-02 12:00:00]
          ),
          purchase(@user_id, "100", timestamp: ~N[2021-01-02 12:01:00]),
          build(:pageview,
            pathname: "/checkout",
            user_id: @other_user_id,
            timestamp: ~N[2021-01-01 12:00:00]
          ),
          purchase(@other_user_id, "300", timestamp: ~N[2021-01-01 12:01:00])
        ])

        resp =
          conn
          |> get(
            "/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&date=2021-01-02&comparison=previous_period"
          )
          |> json_response(200)

        assert %{
                 "steps" => [
                   _checkout_step,
                   %{"revenue" => %{"long" => "$100.00"}}
                 ],
                 "comparison" => %{
                   "steps" => [
                     _previous_checkout_step,
                     %{"revenue" => %{"long" => "$300.00"}}
                   ]
                 }
               } = resp
      end

      test "keeps every step in its own goal's currency", %{conn: conn, site: site} do
        donation = insert(:goal, site: site, event_name: "Donation", currency: "EUR")
        purchase = insert(:goal, site: site, event_name: "Purchase", currency: "USD")
        {:ok, funnel} = funnel_with_goals(site, [donation, purchase])

        populate_stats(site, [
          build(:event,
            name: "Donation",
            user_id: @user_id,
            revenue_reporting_amount: Decimal.new("10"),
            revenue_reporting_currency: "EUR"
          ),
          purchase(@user_id, "50")
        ])

        assert [donation_step, purchase_step] = funnel_steps(conn, site, funnel)

        assert %{"revenue" => %{"long" => "€10.00", "currency" => "EUR"}} = donation_step
        assert %{"revenue" => %{"long" => "$50.00", "currency" => "USD"}} = purchase_step
      end

      test "reports no revenue for a funnel without a revenue goal", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)

        populate_stats(site, [
          build(:pageview, pathname: "/blog/announcement", user_id: @user_id),
          build(:event, name: "Signup", user_id: @user_id)
        ])

        for step <- funnel_steps(conn, site, funnel) do
          refute Map.has_key?(step, "revenue")
          refute Map.has_key?(step, "revenue_per_visitor")
        end
      end

      test "reports no revenue when the site has no access to revenue goals", %{
        conn: conn,
        site: site,
        user: user
      } do
        {:ok, funnel} = setup_checkout_funnel(site)

        site.team
        |> Plausible.Teams.Team.end_trial()
        |> Plausible.Repo.update!()

        subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.Funnels])

        populate_stats(site, [
          build(:pageview, pathname: "/checkout", user_id: @user_id),
          purchase(@user_id, "100")
        ])

        assert [_checkout_step, purchase_step] = funnel_steps(conn, site, funnel)

        refute Map.has_key?(purchase_step, "revenue")
        refute Map.has_key?(purchase_step, "revenue_per_visitor")
      end

      test "reports zero revenue when the payment does not follow the order of a strict-order funnel",
           %{
             conn: conn,
             site: site
           } do
        {:ok, [checkout, signup]} =
          setup_goals(site, [{"page_path", "/checkout"}, {"event_name", "Signup"}])

        purchase = insert(:goal, site: site, event_name: "Purchase", currency: "USD")
        {:ok, funnel} = funnel_with_goals(site, [checkout, signup, purchase], strict_order?: true)

        populate_stats(site, [
          build(:pageview,
            pathname: "/checkout",
            user_id: @user_id,
            timestamp: ~N[2021-01-01 12:00:00]
          ),
          purchase(@user_id, "100", timestamp: ~N[2021-01-01 12:01:00]),
          build(:event,
            name: "Signup",
            user_id: @user_id,
            timestamp: ~N[2021-01-01 12:02:00]
          )
        ])

        assert [_checkout_step, _signup_step, purchase_step] =
                 funnel_steps(conn, site, funnel, "period=day&date=2021-01-01")

        assert %{
                 "visitors" => 0,
                 "revenue" => %{"long" => "$0.00"},
                 "revenue_per_visitor" => %{"long" => "$0.00"}
               } = purchase_step
      end
    end

    defp setup_checkout_funnel(site) do
      {:ok, [checkout]} = setup_goals(site, [{"page_path", "/checkout"}])
      purchase = insert(:goal, site: site, event_name: "Purchase", currency: "USD")

      funnel_with_goals(site, [checkout, purchase])
    end

    defp funnel_with_goals(site, goals, opts \\ []) do
      Plausible.Funnels.create(
        site,
        "Test funnel",
        Enum.map(goals, &%{"goal_id" => &1.id}),
        opts
      )
    end

    defp purchase(user_id, amount, attrs \\ []) do
      build(
        :event,
        Keyword.merge(
          [
            name: "Purchase",
            user_id: user_id,
            revenue_reporting_amount: Decimal.new(amount),
            revenue_reporting_currency: "USD"
          ],
          attrs
        )
      )
    end

    defp funnel_steps(conn, site, funnel, params \\ "period=day") do
      conn
      |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?#{params}")
      |> json_response(200)
      |> Map.fetch!("steps")
    end

    defp setup_goals(site, goals) when is_list(goals) do
      goals =
        Enum.map(goals, fn {type, value} ->
          {:ok, g} = Plausible.Goals.create(site, %{type => value})
          g
        end)

      {:ok, goals}
    end

    defp setup_funnel(site, goal_names, opts \\ []) do
      {:ok, goals} = setup_goals(site, goal_names)

      funnel_with_goals(site, goals, opts)
    end
  end
end
