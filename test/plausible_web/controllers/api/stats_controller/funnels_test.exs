defmodule PlausibleWeb.Api.StatsController.FunnelsTest do
  use PlausibleWeb.ConnCase, async: true

  @user_id 123
  @other_user_id 456

  @build_funnel_with [
    {"page_path", "/blog/announcement"},
    {"event_name", "Signup"},
    {"page_path", "/cart/add/product"},
    {"event_name", "Purchase"}
  ]

  describe "GET /api/stats/funnel - default" do
    setup [:create_user, :log_in, :create_new_site]

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
                   "conversion_rate" => "100.00",
                   "conversion_rate_step" => "0.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
                   "label" => "Visit /blog/announcement",
                   "visitors" => 2
                 },
                 %{
                   "conversion_rate" => "100.00",
                   "conversion_rate_step" => "100.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
                   "label" => "Signup",
                   "visitors" => 2
                 },
                 %{
                   "conversion_rate" => "50.00",
                   "conversion_rate_step" => "50.00",
                   "dropoff" => 1,
                   "dropoff_percentage" => "50.00",
                   "label" => "Visit /cart/add/product",
                   "visitors" => 1
                 },
                 %{
                   "conversion_rate" => "50.00",
                   "conversion_rate_step" => "100.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
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

      assert resp == %{"error" => "There was an error with your request"}
    end

    test "computes all-time funnel with filters", %{conn: conn, user: user} do
      site = insert(:site, stats_start_date: ~D[2020-01-01], members: [user])
      {:ok, funnel} = setup_funnel(site, @build_funnel_with)

      populate_stats(site, [
        build(:pageview, pathname: "/blog/announcement", user_id: @user_id),
        build(:pageview,
          pathname: "/blog/announcement",
          user_id: @other_user_id,
          utm_medium: "social",
          timestamp: ~N[2021-01-01 12:00:00]
        ),
        build(:event, name: "Signup", user_id: @user_id),
        build(:event,
          name: "Signup",
          user_id: @other_user_id,
          utm_medium: "social",
          timestamp: ~N[2021-01-01 12:01:00]
        ),
        build(:pageview, pathname: "/cart/add/product", user_id: @user_id),
        build(:event, name: "Purchase", user_id: @user_id)
      ])

      filters = Jason.encode!(%{utm_medium: "social"})

      resp =
        conn
        |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=all&filters=#{filters}")
        |> json_response(200)

      assert %{
               "name" => "Test funnel",
               "all_visitors" => 1,
               "entering_visitors" => 1,
               "entering_visitors_percentage" => "100.00",
               "never_entering_visitors" => 0,
               "never_entering_visitors_percentage" => "0.00",
               "steps" => [
                 %{
                   "conversion_rate" => "100.00",
                   "conversion_rate_step" => "0.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
                   "label" => "Visit /blog/announcement",
                   "visitors" => 1
                 },
                 %{
                   "conversion_rate" => "100.00",
                   "conversion_rate_step" => "100.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
                   "label" => "Signup",
                   "visitors" => 1
                 },
                 %{
                   "conversion_rate" => "0.00",
                   "conversion_rate_step" => "0.00",
                   "dropoff" => 1,
                   "dropoff_percentage" => "100.00",
                   "label" => "Visit /cart/add/product",
                   "visitors" => 0
                 },
                 %{
                   "conversion_rate" => "0.00",
                   "conversion_rate_step" => "0.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
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
               "entering_visitors_percentage" => "0.00",
               "never_entering_visitors" => 0,
               "never_entering_visitors_percentage" => "0.00",
               "steps" => [
                 %{
                   "conversion_rate" => "0.00",
                   "conversion_rate_step" => "0.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
                   "label" => "Visit /blog/announcement",
                   "visitors" => 0
                 },
                 %{
                   "conversion_rate" => "0.00",
                   "conversion_rate_step" => "0.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
                   "label" => "Signup",
                   "visitors" => 0
                 },
                 %{
                   "conversion_rate" => "0.00",
                   "conversion_rate_step" => "0.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
                   "label" => "Visit /cart/add/product",
                   "visitors" => 0
                 },
                 %{
                   "conversion_rate" => "0.00",
                   "conversion_rate_step" => "0.00",
                   "dropoff" => 0,
                   "dropoff_percentage" => "0.00",
                   "label" => "Purchase",
                   "visitors" => 0
                 }
               ]
             } = resp
    end
  end

  describe "GET /api/stats/funnel - disallowed filters" do
    setup [:create_user, :log_in, :create_new_site]

    test "event:page", %{conn: conn, site: site} do
      {:ok, funnel} = setup_funnel(site, @build_funnel_with)

      filters = Jason.encode!(%{page: "/pageA"})

      resp =
        conn
        |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&filters=#{filters}")
        |> json_response(400)

      assert resp == %{
               "error" => "We are unable to show funnels when the dashboard is filtered by pages",
               "level" => "normal"
             }
    end

    test "event:goal", %{conn: conn, site: site} do
      {:ok, funnel} = setup_funnel(site, @build_funnel_with)

      filters = Jason.encode!(%{goal: "Signup", page: "/pageA"})

      resp =
        conn
        |> get("/api/stats/#{site.domain}/funnels/#{funnel.id}/?period=day&filters=#{filters}")
        |> json_response(400)

      assert resp == %{
               "error" => "We are unable to show funnels when the dashboard is filtered by goals",
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
                 "We are unable to show funnels when the dashboard is filtered by realtime period",
               "level" => "normal"
             }
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
