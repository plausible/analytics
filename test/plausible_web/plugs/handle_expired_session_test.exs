defmodule Plausible.Plugs.HandleExpiredSessionTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible

  on_ee do
    use Plausible.Teams.Test

    alias Plausible.Auth.UserSessions
    alias Plausible.Plugs.HandleExpiredSession
    alias Plausible.Repo

    alias PlausibleWeb.Router.Helpers, as: Routes

    test "passes through when there's no expired_session" do
      conn = HandleExpiredSession.call(build_conn(), [])
      refute conn.halted
    end

    test "passes through when the expired session belongs to standard user" do
      user = new_user()
      in_the_past = NaiveDateTime.add(NaiveDateTime.utc_now(:second), -1, :hour)
      session = UserSessions.create!(user, "Unknown", timeout_at: in_the_past)

      conn =
        build_conn()
        |> assign(:expired_session, session)
        |> HandleExpiredSession.call([])

      refute conn.halted
      assert Repo.reload(session)
    end

    test "halts and redirects to login for expired session of SSO user with return" do
      user = new_user(type: :sso)
      in_the_past = NaiveDateTime.add(NaiveDateTime.utc_now(:second), -1, :hour)
      session = UserSessions.create!(user, "Unknown", timeout_at: in_the_past)

      conn =
        build_conn(:get, "/some/url", %{with: "param"})
        |> assign(:expired_session, session)
        |> HandleExpiredSession.call([])

      assert conn.halted

      assert redirected_to(conn, 302) ==
               Routes.sso_path(conn, :login_form,
                 prefer: "manual",
                 email: user.email,
                 autosubmit: true,
                 return_to: "/some/url?with=param"
               )

      refute Repo.reload(session)
    end

    test "halts and redirects to login without redirect if request method other than GET" do
      user = new_user(type: :sso)
      in_the_past = NaiveDateTime.add(NaiveDateTime.utc_now(:second), -1, :hour)
      session = UserSessions.create!(user, "Unknown", timeout_at: in_the_past)

      conn =
        build_conn(:post, "/some/url")
        |> assign(:expired_session, session)
        |> HandleExpiredSession.call([])

      assert conn.halted

      assert redirected_to(conn, 302) ==
               Routes.sso_path(conn, :login_form,
                 prefer: "manual",
                 email: user.email,
                 autosubmit: true
               )

      refute Repo.reload(session)
    end
  end
end
