defmodule PlausibleWeb.Api.StatsController.ExplorationTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible

  on_ee do
    setup [:create_user, :log_in, :create_site]

    setup %{user: user, site: site} do
      patch_env(:super_admin_user_ids, [user.id])

      now = DateTime.utc_now()

      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          pathname: "/home",
          timestamp: DateTime.shift(now, minute: -300)
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/login",
          timestamp: DateTime.shift(now, minute: -270)
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/home",
          timestamp: DateTime.shift(now, minute: -30)
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/login",
          timestamp: DateTime.shift(now, minute: -25)
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/logout",
          timestamp: DateTime.shift(now, minute: -20)
        ),
        build(:pageview,
          user_id: 124,
          pathname: "/home",
          timestamp: DateTime.shift(now, minute: -30)
        ),
        build(:pageview,
          user_id: 124,
          pathname: "/login",
          timestamp: DateTime.shift(now, minute: -25)
        ),
        build(:pageview,
          user_id: 124,
          pathname: "/docs",
          timestamp: DateTime.shift(now, minute: -20)
        ),
        build(:pageview,
          user_id: 124,
          pathname: "/logout",
          timestamp: DateTime.shift(now, minute: -15)
        )
      ])

      {:ok, site: site}
    end

    describe "exploration_next/2" do
      test "it works", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            %{name: "pageview", pathname: "/home"},
            %{name: "pageview", pathname: "/login"}
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next/", %{
            "journey" => journey,
            "period" => "24h"
          })
          |> json_response(200)

        assert [next_step1, next_step2, next_step3] = resp
        assert next_step1["step"]["pathname"] == "/docs"
        assert next_step1["visitors"] == 1
        assert next_step2["step"]["pathname"] == "/home"
        assert next_step2["visitors"] == 1
        assert next_step3["step"]["pathname"] == "/logout"
        assert next_step3["visitors"] == 1
      end

      test "it filters", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            %{name: "pageview", pathname: "/home"},
            %{name: "pageview", pathname: "/login"}
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next/", %{
            "journey" => journey,
            "search_term" => "doc",
            "period" => "24h"
          })
          |> json_response(200)

        assert [next_step] = resp
        assert next_step["step"]["pathname"] == "/docs"
        assert next_step["visitors"] == 1
      end

      test "it supports backward direction", %{conn: conn, site: site} do
        journey = Jason.encode!([%{name: "pageview", pathname: "/logout"}])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next/", %{
            "journey" => journey,
            "direction" => "backward",
            "period" => "24h"
          })
          |> json_response(200)

        assert [next_step1, next_step2] = resp
        assert next_step1["step"]["pathname"] == "/docs"
        assert next_step1["visitors"] == 1
        assert next_step2["step"]["pathname"] == "/login"
        assert next_step2["visitors"] == 1
      end
    end

    describe "exploration_funnel/2" do
      test "it works", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            %{name: "pageview", pathname: "/home"},
            %{name: "pageview", pathname: "/login"},
            %{name: "pageview", pathname: "/logout"}
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/funnel/", %{
            "journey" => journey,
            "period" => "24h"
          })
          |> json_response(200)

        assert [step1, step2, step3] = resp

        assert step1["step"]["pathname"] == "/home"
        assert step1["visitors"] == 2
        assert step1["dropoff"] == 0
        assert step1["dropoff_percentage"] == "0"
        assert step2["step"]["pathname"] == "/login"
        assert step2["visitors"] == 2
        assert step2["dropoff"] == 0
        assert step2["dropoff_percentage"] == "0"
        assert step3["step"]["pathname"] == "/logout"
        assert step3["visitors"] == 1
        assert step3["dropoff"] == 1
        assert step3["dropoff_percentage"] == "50"
      end

      test "it supports backward direction", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            %{name: "pageview", pathname: "/logout"},
            %{name: "pageview", pathname: "/login"},
            %{name: "pageview", pathname: "/home"}
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/funnel/", %{
            "journey" => journey,
            "direction" => "backward",
            "period" => "24h"
          })
          |> json_response(200)

        assert [step1, step2, step3] = resp

        assert step1["step"]["pathname"] == "/logout"
        assert step1["visitors"] == 1
        assert step1["dropoff"] == 1
        assert step1["dropoff_percentage"] == "50"
        assert step2["step"]["pathname"] == "/login"
        assert step2["visitors"] == 2
        assert step2["dropoff"] == 0
        assert step2["dropoff_percentage"] == "0"
        assert step3["step"]["pathname"] == "/home"
        assert step3["visitors"] == 2
        assert step3["dropoff"] == 0
        assert step3["dropoff_percentage"] == "0"
      end
    end
  end
end
