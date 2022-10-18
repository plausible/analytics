defmodule PlausibleWeb.AdminAuthControllerTest do
  use PlausibleWeb.ConnCase

  describe "GET /" do
    test "no landing page", %{conn: conn} do
      set_config(disable_authentication: false)
      conn = get(conn, "/")
      assert redirected_to(conn) == "/login"
    end

    test "logs admin user in automatically when authentication is disabled", %{conn: conn} do
      set_config(disable_authentication: true)

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

    # https://github.com/plausible/analytics/issues/1271
    test "allows editing admin user email when authentication is disabled", ctx do
      %{conn: conn} = ctx
      set_config(disable_authentication: true)

      og_admin_user =
        insert(:user,
          email: Application.get_env(:plausible, :admin_email),
          password: Application.get_env(:plausible, :admin_pwd)
        )

      # change admin user's email address
      {:ok, admin_user} =
        og_admin_user
        |> Ecto.Changeset.change(%{email: "new-admin@email.com"})
        |> Plausible.Repo.update()

      refute og_admin_user.email == admin_user.email

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
      set_config(disable_registration: true)
      conn = get(conn, "/register")
      assert redirected_to(conn) == "/login"
    end
  end

  def set_config(config) do
    prev_env = Application.get_env(:plausible, :selfhost)
    on_exit(fn -> Application.put_env(:plausible, :selfhost, prev_env) end)

    updated_config =
      Keyword.merge(
        [disable_authentication: false, disable_registration: false],
        config
      )

    Application.put_env(
      :plausible,
      :selfhost,
      updated_config
    )
  end
end
