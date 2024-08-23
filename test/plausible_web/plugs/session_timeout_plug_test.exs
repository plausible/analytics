defmodule PlausibleWeb.SessionTimeoutPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias PlausibleWeb.SessionTimeoutPlug
  @opts %{timeout_after_seconds: 10}

  test "does nothing if user is not logged in" do
    conn =
      conn(:get, "/")
      |> init_test_session(%{})
      |> SessionTimeoutPlug.call(@opts)

    refute get_session(conn, :session_timeout_at)
  end

  test "sets session timeout if user is logged in" do
    conn =
      conn(:get, "/")
      |> init_test_session(%{current_user_id: 1})
      |> SessionTimeoutPlug.call(@opts)

    timeout = get_session(conn, :session_timeout_at)
    now = DateTime.utc_now() |> DateTime.to_unix()
    assert timeout > now
  end

  test "logs user out if timeout passed" do
    conn =
      conn(:get, "/")
      |> init_test_session(%{current_user_id: 1, session_timeout_at: 1})
      |> SessionTimeoutPlug.call(@opts)

    assert conn.private[:plug_session_info] == :renew
  end
end
