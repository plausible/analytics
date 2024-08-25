defmodule PlausibleWeb.UserAuthTest do
  use PlausibleWeb.ConnCase, async: true

  alias Plausible.Auth
  alias Plausible.Repo
  alias PlausibleWeb.UserAuth

  alias PlausibleWeb.Router.Helpers, as: Routes

  describe "log_in_user/2,3" do
    setup [:create_user]

    test "sets up user session and redirects to sites list", %{conn: conn, user: user} do
      conn =
        conn
        |> init_session()
        |> UserAuth.log_in_user(user)

      now = NaiveDateTime.utc_now(:second)

      assert %{sessions: [session]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert session.user_id == user.id
      assert NaiveDateTime.compare(session.last_used_at, now) in [:eq, :gt]
      assert NaiveDateTime.compare(session.timeout_at, session.last_used_at) == :gt

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)
      assert conn.private[:plug_session_info] == :renew
      assert conn.resp_cookies["logged_in"].max_age > 0
      assert get_session(conn, :user_token) == session.token
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
    setup [:create_user]

    test "logs user out", %{conn: conn, user: user} do
      # another independent session for the same user
      {:ok, conn: another_conn} = log_in(%{conn: conn, user: user})
      another_session_token = get_session(another_conn, :user_token)

      {:ok, conn: conn} = log_in(%{conn: conn, user: user})

      conn =
        conn
        |> init_session()
        |> put_session("login_dest", "/ignored")
        |> UserAuth.log_out_user()

      # the other session remains intact
      assert %{sessions: [another_session]} = Repo.preload(user, :sessions)
      assert another_session.token == another_session_token
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
      %{sessions: [user_session]} = Repo.preload(user, :sessions)
      assert {:ok, session_user} = UserAuth.get_user(%{"current_user_id" => user.id})
      assert session_user.id == user.id

      assert {:ok, ^session_user} = UserAuth.get_user(%{"user_token" => user_session.token})
      assert session_user.id == user.id
    end

    test "gets user from session schema", %{user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)

      assert {:ok, session_user} =
               UserAuth.get_user(%Plausible.Auth.UserSession{user_id: user.id})

      assert {:ok, ^session_user} = UserAuth.get_user(user_session)

      assert session_user.id == user.id
    end

    test "returns error on invalid or missing session data" do
      conn = init_session(build_conn())
      assert {:error, :no_valid_token} = UserAuth.get_user(conn)
      assert {:error, :no_valid_token} = UserAuth.get_user(%{})
    end

    test "returns error on missing user (legacy only)", %{user: user} do
      Plausible.Repo.delete!(user)

      assert {:error, :user_not_found} = UserAuth.get_user(%{"current_user_id" => user.id})

      assert {:error, :user_not_found} =
               UserAuth.get_user(%Plausible.Auth.UserSession{user_id: user.id})
    end

    test "returns error on missing session", %{conn: conn, user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)
      Repo.delete!(user_session)

      assert {:error, :session_not_found} = UserAuth.get_user(conn)

      assert {:error, :session_not_found} =
               UserAuth.get_user(%{"user_token" => user_session.token})
    end
  end

  describe "get_user_session/1" do
    setup [:create_user, :log_in]

    test "gets session from session data in conn", %{conn: conn, user: user} do
      assert {:ok, user_session} = UserAuth.get_user_session(conn)
      assert user_session.user_id == user.id
    end

    test "gets session from session data map", %{user: user} do
      user_id = user.id
      %{sessions: [user_session]} = Repo.preload(user, :sessions)

      assert {:ok, ^user_session} =
               UserAuth.get_user_session(%{"user_token" => user_session.token})

      assert {:ok, %Auth.UserSession{user_id: ^user_id, token: nil}} =
               UserAuth.get_user_session(%{"current_user_id" => user.id})
    end

    test "returns error on invalid or missing session data" do
      conn = init_session(build_conn())
      assert {:error, :no_valid_token} = UserAuth.get_user_session(conn)
      assert {:error, :no_valid_token} = UserAuth.get_user_session(%{})
    end

    test "returns error on missing session (new token scaffold; to be revised)", %{
      conn: conn,
      user: user
    } do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)
      Repo.delete!(user_session)

      assert {:error, :session_not_found} = UserAuth.get_user_session(conn)

      assert {:error, :session_not_found} =
               UserAuth.get_user_session(%{"user_token" => user_session.token})
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

  describe "touch_user_session/1" do
    setup [:create_user, :log_in]

    test "refreshes user session timestamps", %{user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)

      two_days_later =
        NaiveDateTime.utc_now(:second)
        |> NaiveDateTime.shift(day: 2)

      assert refreshed_session =
               %Auth.UserSession{} = UserAuth.touch_user_session(user_session, two_days_later)

      assert refreshed_session.id == user_session.id
      assert NaiveDateTime.compare(refreshed_session.last_used_at, two_days_later) == :eq
      assert NaiveDateTime.compare(refreshed_session.timeout_at, user_session.timeout_at) == :gt
    end

    test "skips refreshing legacy session", %{user: user} do
      user_session = %Auth.UserSession{user_id: user.id}

      assert UserAuth.touch_user_session(user_session) == user_session
    end
  end

  describe "convert_legacy_session/1" do
    setup [:create_user, :log_in]

    test "does nothing when there's no authenticated session" do
      conn =
        build_conn()
        |> init_session()
        |> UserAuth.convert_legacy_session()

      refute get_session(conn, :user_token)
      refute get_session(conn, :live_socket_id)
      refute conn.assigns[:current_user_session]
    end

    test "does nothing when there's a new token-based session already", %{conn: conn, user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)

      conn =
        conn
        |> UserAuth.convert_legacy_session()
        |> PlausibleWeb.AuthPlug.call([])

      assert get_session(conn, :user_token) == user_session.token

      assert get_session(conn, :live_socket_id) ==
               "user_sessions:#{Base.url_encode64(user_session.token)}"

      assert conn.assigns.current_user_session.id == user_session.id
    end

    test "converts legacy session to a new one", %{user: user} do
      %{sessions: [existing_session]} = Repo.preload(user, :sessions)

      conn =
        build_conn()
        |> init_session()
        |> put_session(:current_user_id, user.id)
        |> PlausibleWeb.AuthPlug.call([])
        |> UserAuth.convert_legacy_session()

      assert conn.assigns.current_user_session.id
      assert conn.assigns.current_user_session.id != existing_session.id
      assert conn.assigns.current_user_session.token != existing_session.token
      assert conn.assigns.current_user_session.user_id == user.id
      assert conn.assigns.current_user.id == user.id
      refute get_session(conn, :current_user_id)
      assert get_session(conn, :user_token) == conn.assigns.current_user_session.token

      assert get_session(conn, :live_socket_id) ==
               "user_sessions:#{Base.url_encode64(conn.assigns.current_user_session.token)}"
    end
  end

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"
  @user_agent_mobile "Mozilla/5.0 (Linux; Android 6.0; U007 Pro Build/MRA58K; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/44.0.2403.119 Mobile Safari/537.36"
  @user_agent_tablet "Mozilla/5.0 (Linux; U; Android 4.2.2; it-it; Surfing TAB B 9.7 3G Build/JDQ39) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"

  describe "device name detection" do
    setup [:create_user]

    test "detects browser and os when possible", %{conn: conn, user: user} do
      assert login_device(conn, user, @user_agent) == "Chrome (Mac)"
      assert login_device(conn, user, @user_agent_mobile) == "Mobile App (Android)"
      assert login_device(conn, user, @user_agent_tablet) == "Android Browser (Android)"
    end

    test "falls back to unknown when can't detect browser", %{conn: conn, user: user} do
      assert login_device(conn, user, nil) == "Unknown"
      assert login_device(conn, user, "Bogus UA") == "Unknown"
    end

    test "skips os when can't detect it", %{conn: conn, user: user} do
      assert login_device(conn, user, "Mozilla Firefox") == "Firefox"
    end
  end

  defp login_device(conn, user, ua_string) do
    conn =
      if ua_string do
        Plug.Conn.put_req_header(conn, "user-agent", ua_string)
      else
        conn
      end

    {:ok, conn: conn} = log_in(%{conn: conn, user: user})

    {:ok, user_session} = conn |> UserAuth.get_user_session()

    user_session.device
  end
end
