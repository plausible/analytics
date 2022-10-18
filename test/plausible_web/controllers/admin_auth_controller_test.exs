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

      # rate limit workaround
      conn = put_req_header(conn, "x-forwarded-for", "23.23.23.23")

      # goto landing page
      conn = get(conn, "/")
      assert get_session(conn, :current_user_id) == admin_user.id
      assert redirected_to(conn) == "/sites"

      # trying logging out
      conn = recycle(conn, ~w(x-forwarded-for))
      conn = get(conn, "/logout")
      assert redirected_to(conn) == "/"
      conn = recycle(conn, ~w(x-forwarded-for))
      conn = get(conn, "/")
      assert redirected_to(conn) == "/sites"
    end

    test "disable registration", %{conn: conn} do
      set_config(disable_registration: true)
      conn = get(conn, "/register")
      assert redirected_to(conn) == "/login"
    end
  end

  # https://github.com/plausible/analytics/issues/1271
  test "admin user email and password are synced to app env", %{conn: conn} do
    set_config(disable_authentication: true)

    admin_user =
      insert(:user,
        email: Application.get_env(:plausible, :admin_email),
        password: Application.get_env(:plausible, :admin_pwd)
      )

    assert admin_user.email == "admin@email.com"
    assert admin_user.password == "fakepassword"

    # rate limit workaround
    conn = put_req_header(conn, "x-forwarded-for", "24.24.24.24")

    # auto login
    conn = get(conn, "/")

    # change admin user's email address
    new_email = "new-admin@email.com"
    user_params = %{"user" => %{"email" => new_email}}
    conn = recycle(conn, ~w(x-forwarded-for))
    conn = put(conn, "/settings", user_params)
    assert redirected_to(conn) == "/settings"

    # verify the changed email
    admin_user = Plausible.Repo.reload!(admin_user)
    assert admin_user.email == new_email
    assert Application.get_env(:plausible, :admin_email) == new_email

    # change admin user's password
    new_password = "sw0rdfish"
    password_params = %{"password" => new_password}
    conn = recycle(conn, ~w(x-forwarded-for))
    conn = post(conn, "/password", password_params)
    assert redirected_to(conn) == "/sites/new"

    # verify the changed password
    admin_user = Plausible.Repo.reload!(admin_user)
    assert Plausible.Auth.Password.match?(new_password, admin_user.password_hash)
    assert Application.get_env(:plausible, :admin_pwd) == new_password

    # goto landing page
    conn = recycle(conn, ~w(x-forwarded-for))
    conn = get(conn, "/")
    assert get_session(conn, :current_user_id) == admin_user.id
    assert redirected_to(conn) == "/sites"

    # trying logging out
    conn = recycle(conn, ~w(x-forwarded-for))
    conn = get(conn, "/logout")
    assert redirected_to(conn) == "/"
    conn = recycle(conn, ~w(x-forwarded-for))
    conn = get(conn, "/")
    assert redirected_to(conn) == "/sites"
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
