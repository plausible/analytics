defmodule PlausibleWeb.Plugs.UserSessionTouchTest do
  use PlausibleWeb.ConnCase, async: true

  alias Plausible.Repo
  alias PlausibleWeb.AuthPlug
  alias PlausibleWeb.Plugs.UserSessionTouch

  setup [:create_user, :log_in]

  test "refreshes session", %{conn: conn, user: user} do
    now = NaiveDateTime.utc_now(:second)
    one_day_ago = NaiveDateTime.shift(now, day: -1)
    %{sessions: [user_session]} = Repo.preload(user, :sessions)

    user_session
    |> Plausible.Auth.UserSession.touch_session(one_day_ago)
    |> Repo.update!(allow_stale: true)

    assert %{assigns: %{current_user_session: user_session}} =
             conn
             |> AuthPlug.call([])
             |> UserSessionTouch.call([])

    assert NaiveDateTime.compare(user_session.last_used_at, now) in [:gt, :eq]
    assert NaiveDateTime.compare(user_session.timeout_at, user_session.last_used_at) == :gt
  end

  test "passes through when there's no authenticated session" do
    conn =
      build_conn()
      |> init_session()
      |> UserSessionTouch.call([])

    refute conn.halted
    refute get_session(conn, :user_token)
  end
end
