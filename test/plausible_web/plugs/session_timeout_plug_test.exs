defmodule PlausibleWeb.SessionTimeoutPlugTest do
  use Plausible.DataCase, async: true
  use Plug.Test

  import Plausible.Factory

  alias PlausibleWeb.SessionTimeoutPlug

  @opts %{timeout_after_seconds: 10}

  @moduletag :capture_log

  test "does nothing if user is not logged in" do
    conn =
      conn(:get, "/")
      |> init_test_session(%{})
      |> SessionTimeoutPlug.call(@opts)

    refute get_session(conn, :session_timeout_at)
  end

  test "sets session timeout if user is logged in" do
    user = insert(:user)

    conn =
      conn(:get, "/")
      |> init_test_session(%{current_user_id: user.id})
      |> SessionTimeoutPlug.call(@opts)

    timeout = get_session(conn, :session_timeout_at)
    now = DateTime.utc_now() |> DateTime.to_unix()
    assert timeout > now
  end

  test "logs user out if timeout passed" do
    user = insert(:user)

    conn =
      conn(:get, "/")
      |> init_test_session(%{current_user_id: user.id, session_timeout_at: 1})
      |> SessionTimeoutPlug.call(@opts)

    assert conn.private[:plug_session_info] == :renew
    assert conn.halted
    assert Phoenix.ConnTest.redirected_to(conn, 302) == "/login"
  end
end
