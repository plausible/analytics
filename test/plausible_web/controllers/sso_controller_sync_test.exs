defmodule PlausibleWeb.SSOControllerSyncTest do
  use PlausibleWeb.ConnCase

  use Plausible.Teams.Test

  @moduletag :ee_only

  on_ee do
    describe "sso_enabled = false" do
      setup do
        patch_env(:sso_enabled, false)
      end

      test "standard login form does not show link to SSO login", %{conn: conn} do
        conn = get(conn, Routes.auth_path(conn, :login_form))

        assert html = html_response(conn, 200)

        refute html =~ Routes.sso_path(conn, :login_form)
        refute html =~ "Single Sign-on"
      end

      test "sso_settings/2 are guarded by the env var", %{conn: conn} do
        user = new_user()
        team = new_site(owner: user).team |> Plausible.Teams.complete_setup()
        {:ok, ctx} = log_in(%{conn: conn, user: user})
        conn = ctx[:conn]
        conn = set_current_team(conn, team)

        conn = get(conn, Routes.sso_path(conn, :sso_settings))

        assert redirected_to(conn, 302) == "/sites"
      end

      test "sso team settings item is guarded by the env var", %{conn: conn} do
        user = new_user()
        team = new_site(owner: user).team |> Plausible.Teams.complete_setup()
        {:ok, ctx} = log_in(%{conn: conn, user: user})
        conn = ctx[:conn]
        conn = set_current_team(conn, team)

        conn = get(conn, Routes.settings_path(conn, :team_general))

        assert html = html_response(conn, 200)

        refute html =~ "Single Sign-On"
      end

      test "login_form/2 is guarded by the env var", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :login_form))

        assert redirected_to(conn, 302) == "/"
      end

      test "login/2 is guarded by the env var", %{conn: conn} do
        conn = post(conn, Routes.sso_path(conn, :login), %{"email" => "some@example.com"})

        assert redirected_to(conn, 302) == "/"
      end

      test "saml_signin/2 is guarded by the env var", %{conn: conn} do
        conn =
          get(
            conn,
            Routes.sso_path(conn, :saml_signin, Ecto.UUID.generate(),
              email: "some@example.com",
              return_to: "/sites"
            )
          )

        assert redirected_to(conn, 302) == "/"
      end

      test "saml_consume/2 is guarded by the env var", %{conn: conn} do
        conn =
          post(conn, Routes.sso_path(conn, :saml_consume, Ecto.UUID.generate()), %{
            "email" => "some@example.com",
            "return_to" => "/sites"
          })

        assert redirected_to(conn, 302) == "/"
      end

      test "csp_report/2 is guarded by the env var", %{conn: conn} do
        conn = post(conn, Routes.sso_path(conn, :csp_report), %{})

        assert redirected_to(conn, 302) == "/"
      end
    end
  end
end
