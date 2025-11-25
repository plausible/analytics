defmodule PlausibleWeb.RequireAccountPlugTest do
  use PlausibleWeb.ConnCase, async: true

  import Plug.Conn

  alias PlausibleWeb.RequireAccountPlug
  alias PlausibleWeb.Router.Helpers, as: Routes

  describe "enforcing 2FA" do
    test "passes when 2FA enforcement is disabled" do
      user = new_user()
      team = new_site(owner: user).team
      team = Plausible.Teams.complete_setup(team)

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> assign(:current_team, team)
        |> RequireAccountPlug.call(nil)

      refute conn.halted
    end

    test "redirects when 2FA enforcement is enabled" do
      user = new_user()
      team = new_site(owner: user).team
      team = Plausible.Teams.complete_setup(team)
      {:ok, team} = Plausible.Teams.enable_force_2fa(team, user)

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> assign(:current_team, team)
        |> RequireAccountPlug.call(nil)

      assert conn.halted
      assert redirected_to(conn, 302) == Routes.auth_path(conn, :force_initiate_2fa_setup)
    end

    test "does not override for unverified account" do
      user = new_user(email_verified: false)
      team = new_site(owner: user).team
      team = Plausible.Teams.complete_setup(team)
      {:ok, team} = Plausible.Teams.enable_force_2fa(team, user)

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> assign(:current_team, team)
        |> RequireAccountPlug.call(nil)

      assert conn.halted
      assert redirected_to(conn, 302) == Routes.auth_path(conn, :activate_form)
    end

    @force_2fa_exceptions [
      "/2fa/setup/force-initiate",
      "/2fa/setup/initiate",
      "/2fa/setup/verify",
      "/team/select"
    ]

    for path <- @force_2fa_exceptions do
      test "does not redirect if the path is #{path}" do
        user = new_user()
        team = new_site(owner: user).team
        team = Plausible.Teams.complete_setup(team)
        {:ok, team} = Plausible.Teams.enable_force_2fa(team, user)

        conn =
          build_conn(:get, unquote(path))
          |> assign(:current_user, user)
          |> assign(:current_team, team)
          |> RequireAccountPlug.call(nil)

        refute conn.halted
      end
    end
  end
end
