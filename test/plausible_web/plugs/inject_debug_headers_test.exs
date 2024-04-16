defmodule PlausibleWeb.Plugs.InjectDebugHeadersTest do
  use Plausible.DataCase, async: true
  use Plug.Test

  alias PlausibleWeb.Plugs.InjectDebugHeaders
  @prefix "x-plausible-"

  test "does not inject #{@prefix} headers when no queries are registered" do
    conn = :get |> conn("/") |> InjectDebugHeaders.call() |> send_resp(200, "")
    assert Enum.filter(conn.resp_headers, fn {k, _} -> String.starts_with?(k, @prefix) end) == []
  end

  test "injects #{@prefix} headers when queries are registered" do
    :ok = Plausible.DebugReplayInfo.track_query("SELECT * FROM users", "users")
    :ok = Plausible.DebugReplayInfo.track_query("SELECT * FROM accounts", "accounts")

    conn = :get |> conn("/") |> InjectDebugHeaders.call() |> send_resp(200, "")

    assert Enum.filter(conn.resp_headers, fn {k, _} -> String.starts_with?(k, @prefix) end) ==
             [
               {"x-plausible-query-000-users", "SELECT * FROM users"},
               {"x-plausible-query-001-accounts", "SELECT * FROM accounts"}
             ]
  end

  test "skips invalid header chars" do
    :ok = Plausible.DebugReplayInfo.track_query("\nfoo", "trap1")
    :ok = Plausible.DebugReplayInfo.track_query("\rbar", "trap2")
    :ok = Plausible.DebugReplayInfo.track_query("\x00baz", "trap3")
    conn = :get |> conn("/") |> InjectDebugHeaders.call() |> send_resp(200, "")

    assert Enum.filter(conn.resp_headers, fn {k, _} -> String.starts_with?(k, @prefix) end) ==
             [
               {"x-plausible-query-000-trap1", "foo"},
               {"x-plausible-query-001-trap2", "bar"},
               {"x-plausible-query-002-trap3", "baz"}
             ]
  end
end
