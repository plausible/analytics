defmodule PlausibleWeb.Api.CustomerSupport.TeamBillingControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible
  use Plausible.Repo

  on_ee do
    require Plausible.Billing.Subscription.Status
    alias Plausible.Billing.Subscription

    @approval %{"conversation" => "1", "code" => "ABCD", "approved_by" => "marko"}

    setup %{conn: conn} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:billing:*"])
      conn = put_req_header(conn, "authorization", "Bearer #{api_key.key}")

      customer = new_user()
      new_site(owner: customer, domain: "example.com")

      {:ok, conn: conn, customer: customer, team: team_of(customer)}
    end

    test "the billing actions need the cs:billing scope", %{team: team} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:emails:*"])
      Plausible.Teams.start_grace_period(team)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{api_key.key}")
        |> post("/api/cs/v1/teams/#{team.id}/unlock", %{approval: @approval})

      assert json_response(conn, 401)
      assert Repo.reload!(team).grace_period
    end

    describe "unlock and lock" do
      test "unlock lifts the grace period", %{conn: conn, team: team} do
        Plausible.Teams.start_grace_period(team)

        conn = post(conn, "/api/cs/v1/teams/#{team.id}/unlock", %{approval: @approval})

        assert json_response(conn, 200)["result"]["locked"] == false
        refute Repo.reload!(team).grace_period
        assert Repo.get_by(Plausible.Audit.Entry, name: "cs_api_team_unlocked")
      end

      test "lock ends the grace period", %{conn: conn, team: team} do
        Plausible.Teams.start_grace_period(team)

        conn = post(conn, "/api/cs/v1/teams/#{team.id}/lock", %{approval: @approval})

        assert json_response(conn, 200)
        team = Repo.reload!(team)
        assert team.locked
        assert team.grace_period.is_over
      end

      test "both refuse a team without a grace period", %{conn: conn, team: team} do
        assert json_response(
                 post(conn, "/api/cs/v1/teams/#{team.id}/unlock", %{approval: @approval}),
                 422
               )

        assert json_response(
                 post(conn, "/api/cs/v1/teams/#{team.id}/lock", %{approval: @approval}),
                 422
               )

        refute Repo.get_by(Plausible.Audit.Entry, name: "cs_api_team_locked")
      end
    end

    describe "refund lock" do
      test "locks a cancelled subscription and moves the bill date", %{
        conn: conn,
        customer: customer,
        team: team
      } do
        subscribe_to_growth_plan(customer, status: Subscription.Status.deleted())

        conn = post(conn, "/api/cs/v1/teams/#{team.id}/refund_lock", %{approval: @approval})

        assert json_response(conn, 200)
        assert Repo.reload!(team).locked

        assert Date.diff(
                 Plausible.Teams.with_subscription(team).subscription.next_bill_date,
                 Date.utc_today()
               ) == -1
      end

      test "refuses an active subscription", %{conn: conn, customer: customer, team: team} do
        subscribe_to_growth_plan(customer)

        conn = post(conn, "/api/cs/v1/teams/#{team.id}/refund_lock", %{approval: @approval})

        assert json_response(conn, 422)["error"] =~ "isn't cancelled"
        refute Repo.reload!(team).locked
      end
    end

    describe "manual subscription" do
      test "subscribes the team to its latest yearly plan", %{conn: conn, team: team} do
        plan = insert(:enterprise_plan, team: team, billing_interval: :yearly)

        conn =
          post(conn, "/api/cs/v1/teams/#{team.id}/manual_subscription", %{
            approval: @approval,
            enterprise_plan_id: plan.id
          })

        assert json_response(conn, 200)["result"]["manual_subscription"]

        assert Subscription.manual_subscription?(
                 Plausible.Teams.with_subscription(team).subscription
               )
      end

      test "refuses another team's plan", %{conn: conn, team: team} do
        other_plan =
          insert(:enterprise_plan,
            team: team_of(new_user(trial_expiry_date: Date.utc_today())),
            billing_interval: :yearly
          )

        conn =
          post(conn, "/api/cs/v1/teams/#{team.id}/manual_subscription", %{
            approval: @approval,
            enterprise_plan_id: other_plan.id
          })

        assert json_response(conn, 422)["error"] =~ "doesn't belong"
      end
    end
  end
end
