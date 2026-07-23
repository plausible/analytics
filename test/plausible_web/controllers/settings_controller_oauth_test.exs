defmodule PlausibleWeb.SettingsControllerOAuthTest do
  use PlausibleWeb.ConnCase, async: true

  alias Plausible.Repo
  alias Plausible.OAuth.{AccessToken, Token}

  setup [:create_user, :log_in]

  defp insert_grant(user, opts \\ []) do
    {:ok, team} = Plausible.Teams.get_or_create(user)
    access = Token.generate(:access)
    now = DateTime.utc_now()

    Repo.insert!(
      AccessToken.changeset(%{
        access_token_hash: access.hash,
        access_token_prefix: access.prefix,
        client_id:
          Keyword.get(opts, :client_id, "https://claude.ai/oauth/claude-code-client-metadata"),
        client_name: Keyword.get(opts, :client_name, "Claude Code"),
        scopes: ["stats:read:*", "sites:read:*"],
        user_id: user.id,
        team_id: team.id,
        access_token_expires_at: DateTime.add(now, 3600, :second),
        refresh_token_expires_at: DateTime.add(now, 86_400, :second)
      })
    )
  end

  describe "GET /settings/security - connected applications" do
    test "lists the user's grants with a revoke link", %{conn: conn, user: user} do
      grant = insert_grant(user)

      html = conn |> get(Routes.settings_path(conn, :security)) |> html_response(200)

      assert html =~ "Connected applications"
      # Human-readable name, with the CIMD URL shown as a secondary line.
      assert html =~ "Claude Code"
      assert html =~ "https://claude.ai/oauth/claude-code-client-metadata"
      assert html =~ Routes.settings_path(conn, :revoke_oauth_connector, grant.id)
    end

    test "section is hidden when there are no grants and the flag is off", %{conn: conn} do
      html = conn |> get(Routes.settings_path(conn, :security)) |> html_response(200)
      refute html =~ "Connected applications"
    end
  end

  describe "DELETE /settings/security/oauth-connectors/:id" do
    test "revokes the grant", %{conn: conn, user: user} do
      grant = insert_grant(user)

      conn = delete(conn, Routes.settings_path(conn, :revoke_oauth_connector, grant.id))

      assert redirected_to(conn) == Routes.settings_path(conn, :security) <> "#oauth-connectors"
      assert Plausible.OAuth.list_grants(user) == []
    end

    test "cannot revoke another user's grant", %{conn: conn, user: user} do
      other = new_user()
      grant = insert_grant(other)

      conn = delete(conn, Routes.settings_path(conn, :revoke_oauth_connector, grant.id))

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
      assert [_] = Plausible.OAuth.list_grants(other)
      # The current user's own list is unaffected.
      assert Plausible.OAuth.list_grants(user) == []
    end
  end
end
