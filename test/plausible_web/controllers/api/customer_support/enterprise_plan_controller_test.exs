defmodule PlausibleWeb.Api.CustomerSupport.EnterprisePlanControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible
  use Plausible.Repo

  on_ee do
    alias Plausible.Billing.{EnterprisePlan, Subscription}

    @approval %{"conversation" => "3489599858", "code" => "LRUY", "approved_by" => "bogdan"}

    @plan %{
      "paddle_plan_id" => "930841",
      "billing_interval" => "monthly",
      "monthly_pageview_limit" => 100_000,
      "site_limit" => 500,
      "team_member_limit" => 10,
      "hourly_api_request_limit" => 600,
      "features" => ["stats_api", "props", "funnels"]
    }

    setup %{conn: conn} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])

      customer = new_user()
      new_site(owner: customer)
      team = team_of(customer)

      {:ok, conn: conn, automation: automation, customer: customer, team: team}
    end

    defp authorize(conn, user, scopes) do
      api_key = insert(:api_key, user: user, scopes: scopes)
      put_req_header(conn, "authorization", "Bearer #{api_key.key}")
    end

    defp create_plan(conn, team, body) do
      post(conn, "/api/cs/v1/teams/#{team.id}/enterprise_plans", body)
    end

    describe "POST /api/cs/v1/teams/:team_id/enterprise_plans" do
      test "creates the plan and records the approval in the audit log", %{
        conn: conn,
        automation: automation,
        team: team
      } do
        conn =
          conn
          |> authorize(automation, ["cs:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert %{"result" => plan} = json_response(conn, 200)
        assert plan["paddle_plan_id"] == "930841"
        assert plan["site_limit"] == 500
        assert plan["hourly_api_request_limit"] == 600
        assert Enum.sort(plan["features"]) == ["funnels", "props", "stats_api"]

        assert [%EnterprisePlan{billing_interval: :monthly}] =
                 Repo.all(from ep in EnterprisePlan, where: ep.team_id == ^team.id)

        entry = Repo.get_by!(Plausible.Audit.Entry, name: "cs_api_enterprise_plan_created")
        assert entry.team_id == team.id
        assert entry.user_id == automation.id
        assert entry.meta["approval"] == @approval
      end

      test "refuses a request without an approval", %{
        conn: conn,
        automation: automation,
        team: team
      } do
        conn =
          conn
          |> authorize(automation, ["cs:*"])
          |> create_plan(team, @plan)

        assert json_response(conn, 400)["error"] =~ "approval"
        refute Repo.exists?(from ep in EnterprisePlan, where: ep.team_id == ^team.id)
      end

      test "refuses a key without the cs scope", %{
        conn: conn,
        automation: automation,
        team: team
      } do
        conn =
          conn
          |> authorize(automation, ["sites:provision:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 401)
      end

      test "refuses a broad * scope", %{conn: conn, automation: automation, team: team} do
        conn =
          conn
          |> authorize(automation, ["*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 401)
      end

      test "refuses a user who isn't listed for the automation", %{
        conn: conn,
        customer: customer,
        team: team
      } do
        conn =
          conn
          |> authorize(customer, ["cs:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 401)
      end

      test "refuses a super admin who isn't listed for the automation", %{
        conn: conn,
        team: team
      } do
        admin = new_user()
        patch_env(:super_admin_user_ids, [admin.id])

        conn =
          conn
          |> authorize(admin, ["cs:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 401)
        refute Repo.exists?(from ep in EnterprisePlan, where: ep.team_id == ^team.id)
      end

      test "a broad * scope next to a stats scope doesn't reach the CS API", %{
        conn: conn,
        automation: automation,
        team: team
      } do
        conn =
          conn
          |> authorize(automation, ["*", "stats:read:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 401)
        refute Repo.exists?(from ep in EnterprisePlan, where: ep.team_id == ^team.id)
      end

      test "returns 404 for an unknown team", %{conn: conn, automation: automation} do
        conn =
          conn
          |> authorize(automation, ["cs:*"])
          |> post("/api/cs/v1/teams/0/enterprise_plans", Map.put(@plan, "approval", @approval))

        assert json_response(conn, 404)
      end

      test "refuses a team with a manual subscription", %{
        conn: conn,
        automation: automation,
        customer: customer,
        team: team
      } do
        subscribe_to_enterprise_plan(customer,
          paddle_plan_id: Subscription.manual_plan_id(),
          billing_interval: :yearly
        )

        conn =
          conn
          |> authorize(automation, ["cs:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 422)["error"] =~ "manual subscription"
      end

      test "returns 422 with the field when a value is missing", %{
        conn: conn,
        automation: automation,
        team: team
      } do
        conn =
          conn
          |> authorize(automation, ["cs:*"])
          |> create_plan(
            team,
            @plan |> Map.delete("hourly_api_request_limit") |> Map.put("approval", @approval)
          )

        assert json_response(conn, 422)["error"] =~ "hourly_api_request_limit"
      end

      test "refuses a Paddle plan id the team already has", %{
        conn: conn,
        automation: automation,
        team: team
      } do
        insert(:enterprise_plan, team: team, paddle_plan_id: "930841")

        conn =
          conn
          |> authorize(automation, ["cs:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 422)["error"] =~ "paddle_plan_id"
      end

      test "stops at 30 writes in 24 hours", %{conn: conn, automation: automation, team: team} do
        for _ <- 1..30 do
          Repo.insert!(%Plausible.Audit.Entry{
            name: "cs_api_team_unlocked",
            entity: "Plausible.Teams.Team",
            entity_id: "#{team.id}",
            user_id: automation.id,
            team_id: team.id,
            actor_type: :user,
            datetime: NaiveDateTime.utc_now()
          })
        end

        conn =
          conn
          |> authorize(automation, ["cs:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 429)
        refute Repo.exists?(from ep in EnterprisePlan, where: ep.team_id == ^team.id)
      end
    end

    describe "POST /api/cs/v1/teams/:team_id/enterprise_plans/:plan_id" do
      test "updates the plan's limits but never its Paddle plan id", %{
        conn: conn,
        automation: automation,
        team: team
      } do
        plan = insert(:enterprise_plan, team: team, paddle_plan_id: "930841", site_limit: 50)

        conn =
          conn
          |> authorize(automation, ["cs:*"])
          |> post("/api/cs/v1/teams/#{team.id}/enterprise_plans/#{plan.id}", %{
            "approval" => @approval,
            "site_limit" => 500,
            "paddle_plan_id" => "999999"
          })

        assert json_response(conn, 200)["result"]["site_limit"] == 500
        plan = Repo.reload!(plan)
        assert plan.site_limit == 500
        assert plan.paddle_plan_id == "930841"
        assert Repo.get_by(Plausible.Audit.Entry, name: "cs_api_enterprise_plan_updated")
      end

      test "refuses another team's plan", %{conn: conn, automation: automation, team: team} do
        other = new_user()
        new_site(owner: other)
        plan = insert(:enterprise_plan, team: team_of(other), site_limit: 50)

        conn =
          conn
          |> authorize(automation, ["cs:*"])
          |> post("/api/cs/v1/teams/#{team.id}/enterprise_plans/#{plan.id}", %{
            "approval" => @approval,
            "site_limit" => 500
          })

        assert json_response(conn, 404)
        assert Repo.reload!(plan).site_limit == 50
      end
    end
  end
end
