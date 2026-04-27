defmodule PlausibleWeb.Api.StatsController.ExplorationTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible

  on_ee do
    alias Plausible.Stats.Exploration.Journey

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
      test "returns suggestions for the next step", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            Journey.Step.new("pageview", "/home"),
            Journey.Step.new("pageview", "/login")
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next/", %{
            "journey" => journey,
            "period" => "24h"
          })
          |> json_response(200)

        assert [next_step1, next_step2, next_step3] = resp
        assert next_step1["step"]["label"] == "/docs"
        assert next_step1["step"]["pathname"] == "/docs"
        assert next_step1["visitors"] == 1
        assert next_step2["step"]["label"] == "/home"
        assert next_step2["step"]["pathname"] == "/home"
        assert next_step2["visitors"] == 1
        assert next_step3["step"]["label"] == "/logout"
        assert next_step3["step"]["pathname"] == "/logout"
        assert next_step3["visitors"] == 1
      end

      test "returns error on too long journey", %{conn: conn, site: site} do
        journey =
          Jason.encode!(
            Enum.map(1..20, fn idx -> Journey.Step.new("pageview", "/page#{idx}") end)
          )

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next/", %{
            "journey" => journey,
            "period" => "24h"
          })
          |> json_response(400)

        assert resp["error"] == "The journey is too long"
      end

      test "allows filtering suggestions", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            Journey.Step.new("pageview", "/home"),
            Journey.Step.new("pageview", "/login")
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

      test "supports backward direction", %{conn: conn, site: site} do
        journey = Jason.encode!([Journey.Step.new("pageview", "/logout")])

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
      test "returns a funnel", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            Journey.Step.new("pageview", "/home"),
            Journey.Step.new("pageview", "/login"),
            Journey.Step.new("pageview", "/logout")
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/funnel/", %{
            "journey" => journey,
            "period" => "24h"
          })
          |> json_response(200)

        assert [step1, step2, step3] = resp

        assert step1["step"]["label"] == "/home"
        assert step1["step"]["pathname"] == "/home"
        assert step1["visitors"] == 2
        assert step1["dropoff"] == 0
        assert step1["dropoff_percentage"] == "0"
        assert step1["conversion_rate"] == "100"
        assert step1["conversion_rate_step"] == "0"
        assert step2["step"]["label"] == "/login"
        assert step2["step"]["pathname"] == "/login"
        assert step2["visitors"] == 2
        assert step2["dropoff"] == 0
        assert step2["dropoff_percentage"] == "0"
        assert step2["conversion_rate"] == "100"
        assert step2["conversion_rate_step"] == "100"
        assert step3["step"]["label"] == "/logout"
        assert step3["step"]["pathname"] == "/logout"
        assert step3["visitors"] == 1
        assert step3["dropoff"] == 1
        assert step3["dropoff_percentage"] == "50"
        assert step3["conversion_rate"] == "50"
        assert step3["conversion_rate_step"] == "50"
      end

      test "returns error on too long journey", %{conn: conn, site: site} do
        journey =
          Jason.encode!(
            Enum.map(1..21, fn idx -> Journey.Step.new("pageview", "/page#{idx}") end)
          )

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/funnel/", %{
            "journey" => journey,
            "period" => "24h"
          })
          |> json_response(400)

        assert resp["error"] == "The journey is too long"
      end

      test "returns error on empty journey", %{conn: conn, site: site} do
        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/funnel/", %{
            "journey" => Jason.encode!([]),
            "period" => "24h"
          })
          |> json_response(400)

        assert resp["error"] == "We are unable to show funnels when journey is empty"
      end

      test "supports backward direction", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            Journey.Step.new("pageview", "/logout"),
            Journey.Step.new("pageview", "/login"),
            Journey.Step.new("pageview", "/home")
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
        assert step1["visitors"] == 2
        assert step1["dropoff"] == 0
        assert step1["dropoff_percentage"] == "0"
        assert step1["conversion_rate"] == "100"
        assert step1["conversion_rate_step"] == "0"
        assert step2["step"]["pathname"] == "/login"
        assert step2["visitors"] == 1
        assert step2["dropoff"] == 1
        assert step2["dropoff_percentage"] == "50"
        assert step2["conversion_rate"] == "50"
        assert step2["conversion_rate_step"] == "50"
        assert step3["step"]["pathname"] == "/home"
        assert step3["visitors"] == 1
        assert step3["dropoff"] == 0
        assert step3["dropoff_percentage"] == "0"
        assert step3["conversion_rate"] == "50"
        assert step3["conversion_rate_step"] == "100"
      end
    end

    describe "exploration_next_with_funnel/2" do
      test "returns next steps without funnel by default", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            Journey.Step.new("pageview", "/home"),
            Journey.Step.new("pageview", "/login")
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next-with-funnel", %{
            "journey" => journey,
            "period" => "24h"
          })
          |> json_response(200)

        assert [next_step1, next_step2, next_step3] = resp["next"]
        assert next_step1["step"]["label"] == "/docs"
        assert next_step1["step"]["pathname"] == "/docs"
        assert next_step1["visitors"] == 1
        assert next_step2["step"]["label"] == "/home"
        assert next_step2["step"]["pathname"] == "/home"
        assert next_step2["visitors"] == 1
        assert next_step3["step"]["label"] == "/logout"
        assert next_step3["step"]["pathname"] == "/logout"
        assert next_step3["visitors"] == 1

        assert resp["funnel"] == []
      end

      test "filters next steps by search_term", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            Journey.Step.new("pageview", "/home"),
            Journey.Step.new("pageview", "/login")
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next-with-funnel", %{
            "journey" => journey,
            "search_term" => "doc",
            "period" => "24h"
          })
          |> json_response(200)

        assert [next_step] = resp["next"]
        assert next_step["step"]["pathname"] == "/docs"
        assert next_step["visitors"] == 1
        assert resp["funnel"] == []
      end

      test "supports backward direction for next steps", %{conn: conn, site: site} do
        journey = Jason.encode!([Journey.Step.new("pageview", "/logout")])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next-with-funnel", %{
            "journey" => journey,
            "direction" => "backward",
            "period" => "24h"
          })
          |> json_response(200)

        assert [next_step1, next_step2] = resp["next"]
        assert next_step1["step"]["pathname"] == "/docs"
        assert next_step1["visitors"] == 1
        assert next_step2["step"]["pathname"] == "/login"
        assert next_step2["visitors"] == 1
        assert resp["funnel"] == []
      end

      test "includes funnel when include_funnel is true", %{conn: conn, site: site} do
        journey =
          Jason.encode!([
            Journey.Step.new("pageview", "/home"),
            Journey.Step.new("pageview", "/login"),
            Journey.Step.new("pageview", "/logout")
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next-with-funnel", %{
            "journey" => journey,
            "include_funnel" => true,
            "period" => "24h"
          })
          |> json_response(200)

        assert [step1, step2, step3] = resp["funnel"]

        assert step1["step"]["label"] == "/home"
        assert step1["step"]["pathname"] == "/home"
        assert step1["visitors"] == 2
        assert step1["dropoff"] == 0
        assert step1["dropoff_percentage"] == "0"
        assert step1["conversion_rate"] == "100"
        assert step1["conversion_rate_step"] == "0"
        assert step2["step"]["label"] == "/login"
        assert step2["step"]["pathname"] == "/login"
        assert step2["visitors"] == 2
        assert step2["dropoff"] == 0
        assert step2["dropoff_percentage"] == "0"
        assert step2["conversion_rate"] == "100"
        assert step2["conversion_rate_step"] == "100"
        assert step3["step"]["label"] == "/logout"
        assert step3["step"]["pathname"] == "/logout"
        assert step3["visitors"] == 1
        assert step3["dropoff"] == 1
        assert step3["dropoff_percentage"] == "50"
        assert step3["conversion_rate"] == "50"
        assert step3["conversion_rate_step"] == "50"
      end

      test "includes funnel with backward direction when include_funnel is true", %{
        conn: conn,
        site: site
      } do
        journey =
          Jason.encode!([
            Journey.Step.new("pageview", "/logout"),
            Journey.Step.new("pageview", "/login"),
            Journey.Step.new("pageview", "/home")
          ])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next-with-funnel", %{
            "journey" => journey,
            "include_funnel" => true,
            "direction" => "backward",
            "period" => "24h"
          })
          |> json_response(200)

        assert [step1, step2, step3] = resp["funnel"]

        assert step1["step"]["pathname"] == "/logout"
        assert step1["visitors"] == 2
        assert step1["dropoff"] == 0
        assert step1["dropoff_percentage"] == "0"
        assert step1["conversion_rate"] == "100"
        assert step1["conversion_rate_step"] == "0"
        assert step2["step"]["pathname"] == "/login"
        assert step2["visitors"] == 1
        assert step2["dropoff"] == 1
        assert step2["dropoff_percentage"] == "50"
        assert step2["conversion_rate"] == "50"
        assert step2["conversion_rate_step"] == "50"
        assert step3["step"]["pathname"] == "/home"
        assert step3["visitors"] == 1
        assert step3["dropoff"] == 0
        assert step3["dropoff_percentage"] == "0"
        assert step3["conversion_rate"] == "50"
        assert step3["conversion_rate_step"] == "100"
      end

      test "returns empty funnel when include_funnel is true but journey is empty", %{
        conn: conn,
        site: site
      } do
        journey = Jason.encode!([])

        resp =
          conn
          |> post("/api/stats/#{site.domain}/exploration/next-with-funnel", %{
            "journey" => journey,
            "include_funnel" => true,
            "period" => "24h"
          })
          |> json_response(200)

        # An empty journey still returns starting-point candidates for `next`
        assert is_list(resp["next"])
        # Funnel requires at least one step; empty journey yields empty funnel
        assert resp["funnel"] == []
      end
    end
  end
end
