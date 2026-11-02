defmodule PlausibleWeb.SettingsController.ConnectedAppsTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  describe "GET /settings/connected-apps" do
    setup [:create_user, :log_in, :create_team]

    setup %{user: user} do
      FunWithFlags.enable(:mcp, for_actor: user)
      :ok
    end

    test "renders an empty state", %{conn: conn} do
      conn = get(conn, ~p"/settings/connected-apps")

      assert html = html_response(conn, 200)
      assert html =~ "No connected apps"
    end

    test "lists the user's grants", %{
      conn: conn,
      user: user,
      team: team
    } do
      now = NaiveDateTime.utc_now(:second)

      team =
        team
        |> Ecto.Changeset.change(name: "Acme Team")
        |> Repo.update!()
        |> Plausible.Teams.complete_setup()

      used =
        insert(:oauth_grant,
          user: user,
          team: team,
          client_name: "Claude"
        )

      unused =
        insert(:oauth_grant,
          user: user,
          team: team,
          client_name: nil,
          client_id: "https://unnamed.example.com/oauth-metadata"
        )

      revoked =
        insert(:oauth_grant, user: user, team: team, client_name: "Revoked app", revoked_at: now)

      other_user = add_member(team, role: :editor)

      others =
        insert(:oauth_grant, user: other_user, team: team, client_name: "Someone else's app")

      conn = get(conn, ~p"/settings/connected-apps")

      assert html = html_response(conn, 200)

      assert text_of_element(html, "table") =~ "Acme Team"

      assert html =~ "Claude"
      assert html =~ "Client ID: #{used.client_id}"
      assert html =~ ~p"/settings/connected-apps/#{used.id}"

      assert html =~ "https://unnamed.example.com/oauth-metadata"
      refute html =~ "Client ID: https://unnamed.example.com/oauth-metadata"
      assert html =~ ~p"/settings/connected-apps/#{unused.id}"

      refute html =~ "Revoked app"
      refute html =~ ~p"/settings/connected-apps/#{revoked.id}"
      refute html =~ "Someone else"
      refute html =~ ~p"/settings/connected-apps/#{others.id}"
    end

    test "shows the default name for a team that isn't set up", %{
      conn: conn,
      user: user,
      team: team
    } do
      team = team |> Ecto.Changeset.change(name: "Stored name") |> Repo.update!()
      insert(:oauth_grant, user: user, team: team)

      conn = get(conn, ~p"/settings/connected-apps")

      table = conn |> html_response(200) |> text_of_element("table")
      assert table =~ Plausible.Teams.default_name()
      refute table =~ "Stored name"
    end

    test "is not found without the feature flag", %{conn: conn, user: user} do
      FunWithFlags.disable(:mcp, for_actor: user)

      conn = get(conn, ~p"/settings/connected-apps")

      assert html_response(conn, 404)
    end
  end

  describe "DELETE /settings/connected-apps/:id" do
    setup [:create_user, :log_in, :create_team]

    setup %{user: user} do
      FunWithFlags.enable(:mcp, for_actor: user)
      :ok
    end

    test "revokes the grant", %{conn: conn, user: user, team: team} do
      grant = insert(:oauth_grant, user: user, team: team)

      conn = delete(conn, ~p"/settings/connected-apps/#{grant.id}")

      assert redirected_to(conn, 302) == ~p"/settings/connected-apps#connected-apps"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) == "Access revoked successfully"
      assert Repo.reload!(grant).revoked_at
    end

    test "can't revoke a grant that doesn't belong to me", %{conn: conn, team: team} do
      other_user = add_member(team, role: :editor)
      grant = insert(:oauth_grant, user: other_user, team: team)

      conn = delete(conn, ~p"/settings/connected-apps/#{grant.id}")

      assert redirected_to(conn, 302) == ~p"/settings/connected-apps#connected-apps"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Could not find connected app to revoke"

      refute Repo.reload!(grant).revoked_at
    end

    test "is not found without the feature flag", %{conn: conn, user: user, team: team} do
      FunWithFlags.disable(:mcp, for_actor: user)
      grant = insert(:oauth_grant, user: user, team: team)

      conn = delete(conn, ~p"/settings/connected-apps/#{grant.id}")

      assert html_response(conn, 404)
      refute Repo.reload!(grant).revoked_at
    end
  end
end
