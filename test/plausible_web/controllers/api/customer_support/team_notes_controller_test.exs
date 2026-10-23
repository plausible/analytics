defmodule PlausibleWeb.Api.CustomerSupport.TeamNotesControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible
  use Plausible.Repo

  on_ee do
    @approval %{"conversation" => "1", "code" => "ABCD", "approved_by" => "marko"}

    setup %{conn: conn} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:*"])
      conn = put_req_header(conn, "authorization", "Bearer #{api_key.key}")

      customer = new_user()
      new_site(owner: customer)
      team = team_of(customer) |> Ecto.Changeset.change(notes: "Old note") |> Repo.update!()

      {:ok, conn: conn, team: team}
    end

    test "replaces the notes", %{conn: conn, team: team} do
      conn =
        post(conn, "/api/cs/v1/teams/#{team.id}/notes", %{
          approval: @approval,
          previous_notes: "Old note",
          notes: "Old note\nPaid by invoice from 2026"
        })

      assert json_response(conn, 200)["result"]["notes"] =~ "invoice"
      assert Repo.reload!(team).notes == "Old note\nPaid by invoice from 2026"
      assert Repo.get_by(Plausible.Audit.Entry, name: "cs_api_team_notes_updated")
    end

    test "refuses when the notes changed since they were read", %{conn: conn, team: team} do
      conn =
        post(conn, "/api/cs/v1/teams/#{team.id}/notes", %{
          approval: @approval,
          previous_notes: "Something else",
          notes: "New"
        })

      assert json_response(conn, 422)["error"] =~ "changed"
      assert Repo.reload!(team).notes == "Old note"
    end
  end
end
