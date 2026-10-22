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
          |> authorize(automation, ["cs:billing:*"])
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
          |> authorize(automation, ["cs:billing:*"])
          |> create_plan(team, @plan)

        assert json_response(conn, 400)["error"] =~ "approval"
        refute Repo.exists?(from ep in EnterprisePlan, where: ep.team_id == ^team.id)
      end

      test "refuses a key without the cs:billing scope", %{
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
          |> authorize(customer, ["cs:billing:*"])
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
          |> authorize(admin, ["cs:billing:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 401)
        refute Repo.exists?(from ep in EnterprisePlan, where: ep.team_id == ^team.id)
      end

      test "a broad * scope next to another cs: scope doesn't reach billing", %{
        conn: conn,
        automation: automation,
        team: team
      } do
        conn =
          conn
          |> authorize(automation, ["*", "cs:emails:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 401)
        refute Repo.exists?(from ep in EnterprisePlan, where: ep.team_id == ^team.id)
      end

      test "returns 404 for an unknown team", %{conn: conn, automation: automation} do
        conn =
          conn
          |> authorize(automation, ["cs:billing:*"])
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
          |> authorize(automation, ["cs:billing:*"])
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
          |> authorize(automation, ["cs:billing:*"])
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
          |> authorize(automation, ["cs:billing:*"])
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
          |> authorize(automation, ["cs:billing:*"])
          |> create_plan(team, Map.put(@plan, "approval", @approval))

        assert json_response(conn, 429)
        refute Repo.exists?(from ep in EnterprisePlan, where: ep.team_id == ^team.id)
      end
    end
  end
end
