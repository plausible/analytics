defmodule PlausibleWeb.Plugs.NoRobotsTest do
  use Plausible.DataCase, async: true
  use Plug.Test

  alias PlausibleWeb.Plugs.NoRobots

  @sample_non_robot "Mozilla/5.0 (Linux; Android 10; MED-LX9N; HMSCore 5.2.0.318) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 HuaweiBrowser/10.1.2.320 Mobile Safari/537.36"
  @sample_bot "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm) Chrome/103.0.5060.134 Safari/537.36"

  test "non-bots pass - when no user agent is supplied" do
    conn = conn(:get, "/") |> NoRobots.call()
    assert get_resp_header(conn, "x-robots-tag") == ["noindex, nofollow"]
    assert get_resp_header(conn, "x-plausible-forbidden-reason") == []

    refute conn.halted
    refute conn.status
  end

  test "non-bots pass - when user agent is supplied" do
    conn = conn(:get, "/") |> put_req_header("user-agent", @sample_non_robot) |> NoRobots.call()
    assert get_resp_header(conn, "x-robots-tag") == ["noindex, nofollow"]
    assert get_resp_header(conn, "x-plausible-forbidden-reason") == []

    refute conn.halted
    refute conn.status
  end

  test "bots receive 403" do
    conn = conn(:get, "/") |> put_req_header("user-agent", @sample_bot) |> NoRobots.call()

    for _ <- [:cache_commit, :cache_ok] do
      assert get_resp_header(conn, "x-robots-tag") == ["noindex, nofollow"]
      assert get_resp_header(conn, "x-plausible-forbidden-reason") == ["robot"]

      assert conn.halted
      assert conn.status == 403
    end
  end
end
