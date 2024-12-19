defmodule PlausibleWeb.UserAuthTest do
  use PlausibleWeb.ConnCase, async: true

  import Ecto.Query, only: [from: 2]
  import Phoenix.ChannelTest

  alias Plausible.Auth
  alias Plausible.Repo
  alias PlausibleWeb.UserAuth

  alias PlausibleWeb.Router.Helpers, as: Routes

  describe "log_in_user/2,3" do
    setup [:create_user]

    test "sets up user session and redirects to sites list", %{conn: conn, user: user} do
      now = NaiveDateTime.utc_now(:second)

      conn =
        conn
        |> init_session()
        |> UserAuth.log_in_user(user)

      assert %{sessions: [session]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert session.user_id == user.id
      assert NaiveDateTime.compare(session.last_used_at, now) in [:eq, :gt]
      assert NaiveDateTime.compare(session.timeout_at, session.last_used_at) == :gt

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)
      assert conn.private[:plug_session_info] == :renew
      assert conn.resp_cookies["logged_in"].max_age > 0
      assert get_session(conn, :user_token) == session.token
    end

    test "redirects to `redirect_path` if present", %{conn: conn, user: user} do
      conn =
        conn
        |> init_session()
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
        |> UserAuth.log_out_user()

      # the other session remains intact
      assert %{sessions: [another_session]} = Repo.preload(user, :sessions)
      assert another_session.token == another_session_token
      assert conn.private[:plug_session_info] == :renew
      assert conn.resp_cookies["logged_in"].max_age == 0
    end
  end

  describe "get_user_session/1" do
    setup [:create_user, :log_in]

    test "gets session from session data in conn", %{conn: conn, user: user} do
      assert {:ok, user_session} = UserAuth.get_user_session(conn)
      assert user_session.user_id == user.id
    end

    test "gets session from session data map", %{user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)

      assert {:ok, session_from_token} =
               UserAuth.get_user_session(%{"user_token" => user_session.token})

      assert session_from_token.id == user_session.id
    end

    test "returns error on invalid or missing session data" do
      conn = init_session(build_conn())
      assert {:error, :no_valid_token} = UserAuth.get_user_session(conn)
      assert {:error, :no_valid_token} = UserAuth.get_user_session(%{})
      assert {:error, :no_valid_token} = UserAuth.get_user_session(%{"current_user_id" => 123})
    end

    test "returns error on missing session", %{
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
      assert NaiveDateTime.compare(Repo.reload(user).last_seen, two_days_later) == :eq
      assert NaiveDateTime.compare(refreshed_session.timeout_at, user_session.timeout_at) == :gt
    end

    test "does not refresh if timestamps were updated less than hour before", %{user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)
      user_session = Repo.reload(user_session)
      last_seen = Repo.reload(user).last_seen

      fifty_minutes_later =
        NaiveDateTime.utc_now(:second)
        |> NaiveDateTime.shift(minute: 50)

      assert refreshed_session1 =
               %Auth.UserSession{} =
               UserAuth.touch_user_session(user_session, fifty_minutes_later)

      assert NaiveDateTime.compare(
               refreshed_session1.last_used_at,
               user_session.last_used_at
             ) == :eq

      assert NaiveDateTime.compare(Repo.reload(user).last_seen, last_seen) == :eq

      sixty_five_minutes_later =
        NaiveDateTime.utc_now(:second)
        |> NaiveDateTime.shift(minute: 65)

      assert refreshed_session2 =
               %Auth.UserSession{} =
               UserAuth.touch_user_session(user_session, sixty_five_minutes_later)

      assert NaiveDateTime.compare(
               refreshed_session2.last_used_at,
               sixty_five_minutes_later
             ) == :eq

      assert NaiveDateTime.compare(Repo.reload(user).last_seen, sixty_five_minutes_later) == :eq
    end

    test "handles concurrent refresh gracefully", %{user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)

      # concurrent update
      now = NaiveDateTime.utc_now(:second)
      two_days_later = NaiveDateTime.shift(now, day: 2)

      Repo.update_all(
        from(us in Auth.UserSession, where: us.token == ^user_session.token),
        set: [timeout_at: two_days_later, last_used_at: now]
      )

      assert refreshed_session =
               %Auth.UserSession{} = UserAuth.touch_user_session(user_session)

      assert refreshed_session.id == user_session.id
      assert Repo.reload(user_session)
    end

    test "handles deleted session case gracefully", %{user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)
      Repo.delete!(user_session)

      assert refreshed_session =
               %Auth.UserSession{} = UserAuth.touch_user_session(user_session)

      assert refreshed_session.id == user_session.id

      refute Repo.reload(user_session)
    end
  end

  describe "revoke_user_session/2" do
    setup [:create_user, :log_in]

    test "deletes and disconnects user session", %{user: user} do
      assert [active_session] = Repo.preload(user, :sessions).sessions
      live_socket_id = "user_sessions:" <> Base.url_encode64(active_session.token)
      Phoenix.PubSub.subscribe(Plausible.PubSub, live_socket_id)

      another_session =
        user
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      assert :ok = UserAuth.revoke_user_session(user, active_session.id)
      assert [remaining_session] = Repo.preload(user, :sessions).sessions
      assert_broadcast "disconnect", %{}
      assert remaining_session.id == another_session.id
      refute Repo.reload(active_session)
      assert Repo.reload(another_session)
    end

    test "does not delete session of another user", %{user: user} do
      assert [active_session] = Repo.preload(user, :sessions).sessions

      other_session =
        insert(:user)
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      assert :ok = UserAuth.revoke_user_session(user, other_session.id)

      assert Repo.reload(active_session)
      assert Repo.reload(other_session)
    end

    test "executes gracefully when session does not exist", %{user: user} do
      assert [active_session] = Repo.preload(user, :sessions).sessions
      Repo.delete!(active_session)

      assert :ok = UserAuth.revoke_user_session(user, active_session.id)
    end
  end

  describe "revoke_all_user_sessions/1" do
    setup [:create_user, :log_in]

    test "deletes and disconnects all user's sessions", %{user: user} do
      assert [active_session] = Repo.preload(user, :sessions).sessions
      live_socket_id = "user_sessions:" <> Base.url_encode64(active_session.token)
      Phoenix.PubSub.subscribe(Plausible.PubSub, live_socket_id)

      another_session =
        user
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      unrelated_session =
        insert(:user)
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      assert :ok = UserAuth.revoke_all_user_sessions(user)
      assert [] = Repo.preload(user, :sessions).sessions
      assert_broadcast "disconnect", %{}
      refute Repo.reload(another_session)
      assert Repo.reload(unrelated_session)
    end

    test "executes gracefully when user has no sessions" do
      user = insert(:user)

      assert :ok = UserAuth.revoke_all_user_sessions(user)
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
