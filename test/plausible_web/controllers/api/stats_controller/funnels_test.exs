defmodule PlausibleWeb.Api.StatsController.FunnelsTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible
  use Plausible.Teams.Test
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

        assert_matches %{"error" => "There was an error with your request"} = resp
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
                   "Funnels is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
               } == resp
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

        assert_matches %{
                         "error" =>
                           "We are unable to show funnels when the dashboard is filtered by pages",
                         "level" => "normal"
                       } = resp
      end

      test "event:goal", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)

        filters =
          Jason.encode!([[:is, "event:goal", ["Signup"]], [:is, "event:page", ["/pageA"]]])

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&filters=#{filters}")
          |> json_response(400)

        assert_matches %{
                         "error" =>
                           "We are unable to show funnels when the dashboard is filtered by goals",
                         "level" => "normal"
                       } = resp
      end

      test "period: realtime", %{conn: conn, site: site} do
        {:ok, funnel} = setup_funnel(site, @build_funnel_with)

        resp =
          conn
          |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=realtime")
          |> json_response(400)

        assert_matches %{
                         "error" =>
                           "We are unable to show funnels when the dashboard is filtered by realtime period",
                         "level" => "normal"
                       } = resp
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

    defp setup_goals(site, goals) when is_list(goals) do
      goals =
        Enum.map(goals, fn {type, value} ->
          {:ok, g} = Plausible.Goals.create(site, %{type => value})
          g
        end)

      {:ok, goals}
    end

    defp setup_funnel(site, goal_names) do
      {:ok, goals} = setup_goals(site, goal_names)
      Plausible.Funnels.create(site, "Test funnel", Enum.map(goals, &%{"goal_id" => &1.id}))
    end
  end
end
