defmodule PlausibleWeb.UserAuthTest do
  use PlausibleWeb.ConnCase, async: true

  alias PlausibleWeb.UserAuth

  alias PlausibleWeb.Router.Helpers, as: Routes

  describe "log_in_user/2,3" do
    setup [:create_user]

    test "sets up user session and redirects to sites list", %{conn: conn, user: user} do
      conn =
        conn
        |> init_session()
        |> UserAuth.log_in_user(user)

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)
      assert conn.private[:plug_session_info] == :renew
      assert conn.resp_cookies["logged_in"].max_age > 0
      assert get_session(conn, :current_user_id) == user.id
      assert get_session(conn, :login_dest) == nil
    end

    test "redirects to `login_dest` if present", %{conn: conn, user: user} do
      conn =
        conn
        |> init_session()
        |> put_session("login_dest", "/next")
        |> UserAuth.log_in_user(user)

      assert redirected_to(conn, 302) == "/next"
    end

    test "redirects to `redirect_path` if present", %{conn: conn, user: user} do
      conn =
        conn
        |> init_session()
        |> UserAuth.log_in_user(user, "/next")

      assert redirected_to(conn, 302) == "/next"
    end

    test "redirect_path` has precednce over `login_dest`", %{conn: conn, user: user} do
      conn =
        conn
        |> init_session()
        |> put_session("login_dest", "/ignored")
        |> UserAuth.log_in_user(user, "/next")

      assert redirected_to(conn, 302) == "/next"
    end
  end

  describe "log_out_user/1" do
    setup [:create_user, :log_in]

    test "logs user out", %{conn: conn} do
      conn =
        conn
        |> init_session()
        |> put_session("login_dest", "/ignored")
        |> UserAuth.log_out_user()

      assert conn.private[:plug_session_info] == :renew
      assert conn.resp_cookies["logged_in"].max_age == 0
      assert get_session(conn, :current_user_id) == nil
      assert get_session(conn, :login_dest) == nil
    end
  end

  describe "get_user/1" do
    setup [:create_user, :log_in]

    test "gets user from session data in conn", %{conn: conn, user: user} do
      assert {:ok, session_user} = UserAuth.get_user(conn)
      assert session_user.id == user.id
    end

    test "gets user from session data map", %{user: user} do
      assert {:ok, session_user} = UserAuth.get_user(%{"current_user_id" => user.id})
      assert session_user.id == user.id
    end

    test "gets user from session schema", %{user: user} do
      assert {:ok, session_user} =
               UserAuth.get_user(%Plausible.Auth.UserSession{user_id: user.id})

      assert session_user.id == user.id
    end

    test "returns error on invalid or missing session data" do
      conn = init_session(build_conn())
      assert {:error, :no_valid_token} = UserAuth.get_user(conn)
      assert {:error, :no_valid_token} = UserAuth.get_user(%{})
    end

    test "returns error on missing user", %{conn: conn, user: user} do
      Plausible.Repo.delete!(user)

      assert {:error, :user_not_found} = UserAuth.get_user(conn)
      assert {:error, :user_not_found} = UserAuth.get_user(%{"current_user_id" => user.id})

      assert {:error, :user_not_found} =
               UserAuth.get_user(%Plausible.Auth.UserSession{user_id: user.id})
    end

    test "returns error on missing session (new token scaffold; to be revised)" do
      conn = build_conn() |> init_session() |> put_session(:user_token, "does_not_exist")

      assert {:error, :session_not_found} = UserAuth.get_user(conn)
      assert {:error, :session_not_found} = UserAuth.get_user(%{"user_token" => "does_not_exist"})
    end
  end

  describe "get_user_session/1" do
    setup [:create_user, :log_in]

    test "gets session from session data in conn", %{conn: conn, user: user} do
      assert {:ok, user_session} = UserAuth.get_user_session(conn)
      assert user_session.user_id == user.id
    end

    test "gets session from session data map", %{user: user} do
      assert {:ok, user_session} = UserAuth.get_user_session(%{"current_user_id" => user.id})
      assert user_session.user_id == user.id
    end

    test "returns error on invalid or missing session data" do
      conn = init_session(build_conn())
      assert {:error, :no_valid_token} = UserAuth.get_user_session(conn)
      assert {:error, :no_valid_token} = UserAuth.get_user_session(%{})
    end

    test "returns error on missing session (new token scaffold; to be revised)" do
      conn = build_conn() |> init_session() |> put_session(:user_token, "does_not_exist")

      assert {:error, :session_not_found} = UserAuth.get_user_session(conn)

      assert {:error, :session_not_found} =
               UserAuth.get_user_session(%{"user_token" => "does_not_exist"})
    end
  end

  describe "set_logged_in_cookie/1" do
    test "sets logged_in_cookie", %{conn: conn} do
      conn = UserAuth.set_logged_in_cookie(conn)

      assert cookie = conn.resp_cookies["logged_in"]
      assert cookie.max_age > 0
      assert cookie.value == "true"
    end
  end
end
