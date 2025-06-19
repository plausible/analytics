defmodule Plausible.Plugs.SSOTeamAccessTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible

  on_ee do
    use Plausible.Teams.Test

    alias Plausible.Auth
    alias Plausible.Plugs.SSOTeamAccess
    alias PlausibleWeb.AuthPlug

    describe "no user" do
      test "passes through when there's no user" do
        conn = SSOTeamAccess.call(build_conn(), [])
        refute conn.halted
      end
    end

    describe "no team" do
      setup [:create_user, :log_in]

      test "passes through when there's no team", %{conn: conn} do
        conn =
          conn
          |> Plug.Conn.fetch_query_params()
          |> AuthPlug.call([])
          |> SSOTeamAccess.call([])

        refute conn.halted
      end
    end

    describe "non-SSO team" do
      setup [:create_user, :create_team, :log_in, :setup_team]

      test "passes through for non-SSO team", %{conn: conn} do
        conn =
          conn
          |> Plug.Conn.fetch_query_params()
          |> AuthPlug.call([])
          |> SSOTeamAccess.call([])

        refute conn.halted
      end
    end

    describe "SSO team with provisioned user" do
      setup [
        :create_user,
        :create_site,
        :create_team,
        :setup_sso,
        :provision_sso_user,
        :log_in,
        :setup_team
      ]

      test "passes for SSO team without force SSO", %{conn: conn} do
        conn =
          conn
          |> Plug.Conn.fetch_query_params()
          |> AuthPlug.call([])
          |> SSOTeamAccess.call([])

        refute conn.halted
      end

      test "passes for SSO team with force SSO", %{conn: conn, team: team, user: user} do
        {:ok, user, _} = Auth.TOTP.initiate(user)
        {:ok, _user, _} = Auth.TOTP.enable(user, :skip_verify)
        {:ok, _team} = Auth.SSO.set_force_sso(team, :all_but_owners)

        conn =
          conn
          |> Plug.Conn.fetch_query_params()
          |> AuthPlug.call([])
          |> SSOTeamAccess.call([])

        refute conn.halted
      end
    end

    describe "SSO team with non-provisioned user" do
      setup [:create_user, :create_site, :create_team, :setup_sso, :log_in, :setup_team]

      test "passes for SSO team without force SSO", %{conn: conn} do
        conn =
          conn
          |> Plug.Conn.fetch_query_params()
          |> AuthPlug.call([])
          |> SSOTeamAccess.call([])

        refute conn.halted
      end

      test "redirects to notice for SSO team with force SSO", %{
        conn: conn,
        team: team,
        user: user
      } do
        {:ok, user, _} = Auth.TOTP.initiate(user)
        {:ok, _user, _} = Auth.TOTP.enable(user, :skip_verify)
        identity = new_identity("Woozy Wooster", "woozy@example.com")
        Auth.SSO.provision_user(identity)
        {:ok, _team} = Auth.SSO.set_force_sso(team, :all_but_owners)

        conn =
          conn
          |> Plug.Conn.fetch_query_params()
          |> AuthPlug.call([])
          |> SSOTeamAccess.call([])

        assert conn.halted
        assert redirected_to(conn, 302) == Routes.sso_path(conn, :provision_notice)
      end

      test "redirects to issue notice for SSO team with force SSO and user in invalid state", %{
        conn: conn,
        team: team,
        user: user
      } do
        another_team = new_site().team |> Plausible.Teams.complete_setup()
        add_member(another_team, user: user, role: :viewer)

        {:ok, user, _} = Auth.TOTP.initiate(user)
        {:ok, _user, _} = Auth.TOTP.enable(user, :skip_verify)
        identity = new_identity("Woozy Wooster", "woozy@example.com")
        Auth.SSO.provision_user(identity)
        {:ok, _team} = Auth.SSO.set_force_sso(team, :all_but_owners)

        conn =
          conn
          |> Plug.Conn.fetch_query_params()
          |> AuthPlug.call([])
          |> SSOTeamAccess.call([])

        assert conn.halted

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :provision_issue, issue: "multiple_memberships")
      end
    end
  end
end
