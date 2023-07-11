defmodule PlausibleWeb.Plugs.NoRobotsTest do
  use Plausible.DataCase, async: true
  use Plug.Test

  alias PlausibleWeb.Plugs.NoRobots

  test "non-bots pass - when no user agent is supplied" do
    conn = :get |> conn("/") |> NoRobots.call()
    assert get_resp_header(conn, "x-robots-tag") == ["noindex, nofollow"]
    assert get_resp_header(conn, "x-plausible-forbidden-reason") == []
    assert conn.private.robots == "noindex, nofollow"

    refute conn.halted
    refute conn.status
  end

  test "non-bots pass - when user agent is supplied" do
    conn = :get |> conn("/") |> NoRobots.call()
    assert get_resp_header(conn, "x-robots-tag") == ["noindex, nofollow"]
    assert get_resp_header(conn, "x-plausible-forbidden-reason") == []
    assert conn.private.robots == "noindex, nofollow"

    refute conn.halted
    refute conn.status
  end

  test "writes index, nofollow for plausible.io live demo" do
    conn = :get |> conn("/plausible.io") |> NoRobots.call()

    assert get_resp_header(conn, "x-robots-tag") == ["index, nofollow"]
    assert get_resp_header(conn, "x-plausible-forbidden-reason") == []

    refute conn.halted
    refute conn.status
  end
end
