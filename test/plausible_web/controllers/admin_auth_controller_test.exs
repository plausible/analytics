defmodule PlausibleWeb.AdminAuthControllerTest do
  use PlausibleWeb.ConnCase
  alias Plausible.Release

  setup_patch_env(:is_selfhost, true)

  describe "GET /" do
    test "no landing page", %{conn: conn} do
      prevent_first_launch()
      patch_config(disable_authentication: false)
      conn = get(conn, "/")
      assert redirected_to(conn) == "/login"
    end

    test "logs admin user in automatically when authentication is disabled", %{conn: conn} do
      patch_config(disable_authentication: true)

      admin_user =
        insert(:user,
          email: Application.get_env(:plausible, :admin_email),
          password: Application.get_env(:plausible, :admin_pwd)
        )

      # goto landing page
      conn = get(conn, "/")
      assert get_session(conn, :current_user_id) == admin_user.id
      assert redirected_to(conn) == "/sites"

      # trying logging out
      conn = get(conn, "/logout")
      assert redirected_to(conn) == "/"
      conn = get(conn, "/")
      assert redirected_to(conn) == "/sites"
    end

    test "disable registration", %{conn: conn} do
      prevent_first_launch()
      patch_config(disable_registration: true)
      conn = get(conn, "/register")
      assert redirected_to(conn) == "/login"
    end

    test "disable registration + first launch", %{conn: conn} do
      patch_config(disable_registration: true)
      assert Release.should_be_first_launch?()

      # "first launch" takes precedence
      conn = get(conn, "/register")
      assert html_response(conn, 200) =~ "Enter your details"
    end
  end

  def patch_config(config) do
    updated_config =
      Keyword.merge(
        [disable_authentication: false, disable_registration: false],
        config
      )

    patch_env(:selfhost, updated_config)
  end

  defp prevent_first_launch do
    insert(:user)
  end
end
