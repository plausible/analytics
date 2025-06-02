defmodule PlausibleWeb.SSOControllerSyncTest do
  use PlausibleWeb.ConnCase

  @moduletag :ee_only

  on_ee do
    setup do
      patch_env(:sso_enabled, false)
    end

    test "standard login form does not show link to SSO login", %{conn: conn} do
      conn = get(conn, Routes.auth_path(conn, :login_form))

      assert html = html_response(conn, 200)

      refute html =~ Routes.sso_path(conn, :login_form)
      refute html =~ "Single Sign-on"
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
