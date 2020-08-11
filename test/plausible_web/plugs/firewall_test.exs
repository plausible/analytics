defmodule PlausibleWeb.FirewallTest do
  use Plausible.DataCase
  use Plug.Test
  alias PlausibleWeb.Firewall

  @allowed_ip "127.0.0.2"
  @blocked_ip "127.0.0.1"
  @opts [blocklist: [@blocked_ip]]


  test "ignores request if IP is allowed" do
    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", @allowed_ip)
      |> Firewall.call(@opts)

    assert conn.status == nil
  end

  test "responds with 404 if IP is blocked" do
    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", @blocked_ip)
      |> Firewall.call(@opts)

    assert conn.status == 404
  end
end
