defmodule PlausibleWeb.Api.CustomerSupport.TeamTrialAndDeletionControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible
  use Plausible.Repo

  on_ee do
    @approval %{"conversation" => "1", "code" => "ABCD", "approved_by" => "marko"}

    setup %{conn: conn} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])

      api_key =
        insert(:api_key, user: automation, scopes: ["cs:trials:*", "cs:deletions:*"])

      conn = put_req_header(conn, "authorization", "Bearer #{api_key.key}")

      customer = new_user(trial_expiry_date: Date.add(Date.utc_today(), 5))
      site = new_site(owner: customer, domain: "old.example.com")

      {:ok, conn: conn, customer: customer, team: team_of(customer), site: site}
    end

    describe "trial" do
      test "sets both dates", %{conn: conn, team: team} do
        # Both later than the team's current dates, as an extension is.
        expiry = Date.add(team.trial_expiry_date, 15)
        accept = Date.add(team.accept_traffic_until, 15)

        conn =
          post(conn, "/api/cs/v1/teams/#{team.id}/trial", %{
            approval: @approval,
            trial_expiry_date: Date.to_iso8601(expiry),
            accept_traffic_until: Date.to_iso8601(accept)
          })

        assert json_response(conn, 200)
        team = Repo.reload!(team)
        assert team.trial_expiry_date == expiry
        assert team.accept_traffic_until == accept
      end

      test "refuses an earlier date", %{conn: conn, team: team} do
        conn =
          post(conn, "/api/cs/v1/teams/#{team.id}/trial", %{
            approval: @approval,
            trial_expiry_date: Date.to_iso8601(Date.utc_today()),
            accept_traffic_until: Date.to_iso8601(Date.add(Date.utc_today(), 60))
          })

        assert json_response(conn, 422)["error"] =~ "isn't later"
      end

      test "block ends the trial today and adds a note", %{conn: conn, team: team} do
        conn =
          post(conn, "/api/cs/v1/teams/#{team.id}/block_trial", %{
            approval: @approval,
            note: "repeat trials, #40000"
          })

        assert json_response(conn, 200)
        team = Repo.reload!(team)
        assert team.trial_expiry_date == Date.utc_today()
        assert team.accept_traffic_until == Date.utc_today()
        assert team.notes =~ "trial blocked: repeat trials, #40000"
      end

      test "block refuses a note of more than one line", %{conn: conn, team: team} do
        conn =
          post(conn, "/api/cs/v1/teams/#{team.id}/block_trial", %{
            approval: @approval,
            note: "repeat trials\nsee #40000"
          })

        assert json_response(conn, 422)["error"] =~ "One line only"
        refute Repo.reload!(team).trial_expiry_date == Date.utc_today()
      end

      test "block refuses a team that has subscribed", %{
        conn: conn,
        customer: customer,
        team: team
      } do
        subscribe_to_growth_plan(customer)

        conn =
          post(conn, "/api/cs/v1/teams/#{team.id}/block_trial", %{approval: @approval, note: "x"})

        assert json_response(conn, 422)
      end

      test "upgrade override", %{conn: conn, team: team} do
        conn = post(conn, "/api/cs/v1/teams/#{team.id}/upgrade_override", %{approval: @approval})
        assert json_response(conn, 200)
        assert Repo.reload!(team).allow_next_upgrade_override
      end
    end

    describe "deletion schedule" do
      test "snooze and unsnooze", %{conn: conn, team: team} do
        schedule = insert(:team_deletion_schedule, team: team, status: :scheduled)
        until = Date.add(Date.utc_today(), 30)

        conn1 =
          post(conn, "/api/cs/v1/teams/#{team.id}/deletion_schedule/snooze", %{
            approval: @approval,
            snoozed_until: Date.to_iso8601(until),
            snooze_note: "customer asked, #40000"
          })

        assert json_response(conn1, 200)
        assert %{status: :snoozed, snoozed_until: ^until} = Repo.reload!(schedule)

        conn2 =
          post(conn, "/api/cs/v1/teams/#{team.id}/deletion_schedule/unsnooze", %{
            approval: @approval
          })

        assert json_response(conn2, 200)
        assert Repo.reload!(schedule).status == :scheduled
      end

      test "snooze refuses a team without a schedule", %{conn: conn, team: team} do
        conn =
          post(conn, "/api/cs/v1/teams/#{team.id}/deletion_schedule/snooze", %{
            approval: @approval,
            snoozed_until: Date.to_iso8601(Date.add(Date.utc_today(), 30))
          })

        assert json_response(conn, 422)["error"] =~ "no deletion scheduled"
      end
    end

    describe "delete site" do
      test "refuses while the trial runs", %{conn: conn, site: site} do
        conn =
          post(conn, "/api/cs/v1/sites/#{site.id}/delete", %{
            approval: @approval,
            domain: site.domain
          })

        assert json_response(conn, 422)["error"] =~ "trial"
        assert Repo.reload(site)
      end

      test "deletes the site of an expired trial", %{conn: conn, team: team, site: site} do
        team
        |> Ecto.Changeset.change(trial_expiry_date: Date.add(Date.utc_today(), -40))
        |> Repo.update!()

        conn =
          post(conn, "/api/cs/v1/sites/#{site.id}/delete", %{
            approval: @approval,
            domain: site.domain
          })

        assert json_response(conn, 200)["result"]["deleted"]
        refute Repo.reload(site)
      end

      test "refuses a wrong domain", %{conn: conn, team: team, site: site} do
        team
        |> Ecto.Changeset.change(trial_expiry_date: Date.add(Date.utc_today(), -40))
        |> Repo.update!()

        conn =
          post(conn, "/api/cs/v1/sites/#{site.id}/delete", %{
            approval: @approval,
            domain: "other.example.com"
          })

        assert json_response(conn, 422)["error"] =~ "domain"
        assert Repo.reload(site)
      end
    end
  end
end
