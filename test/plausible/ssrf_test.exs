defmodule Plausible.SSRFTest do
  # Not async: patches the global address check.
  use ExUnit.Case, async: false
  use Plausible.Test.Support.DNS

  alias Plausible.SSRF
  alias Plausible.Test.Support.TLSServer

  require TLSServer

  describe "resolve_host/1" do
    test "rejects bare single-label hosts (no dot)" do
      expect_no_dns_lookup()

      assert SSRF.resolve_host("localhost") == {:error, :invalid_host}
      assert SSRF.resolve_host("metadata") == {:error, :invalid_host}
    end

    test "validates a literal public IPv4 host directly, without any DNS lookup" do
      expect_no_dns_lookup()

      assert SSRF.resolve_host("93.184.216.34") == {:ok, [{93, 184, 216, 34}]}
    end

    test "rejects a literal private/loopback/link-local IPv4 host, without any DNS lookup" do
      expect_no_dns_lookup()

      assert SSRF.resolve_host("127.0.0.1") == {:error, :restricted_address}
      assert SSRF.resolve_host("10.0.0.1") == {:error, :restricted_address}
      assert SSRF.resolve_host("169.254.169.254") == {:error, :restricted_address}
    end

    test "rejects a literal private/loopback IPv6 host, without any DNS lookup" do
      expect_no_dns_lookup()

      assert SSRF.resolve_host("::1") == {:error, :restricted_address}
      assert SSRF.resolve_host("fc00::1") == {:error, :restricted_address}
    end

    test "resolves a domain via DNS to a public address" do
      stub_dns(%{"example.com" => {[{93, 184, 216, 34}], []}})

      assert SSRF.resolve_host("example.com") == {:ok, [{93, 184, 216, 34}]}
    end

    test "rejects a domain whose only DNS answer is a private/reserved address" do
      stub_dns(%{"example.com" => {[{192, 168, 1, 1}], []}})

      assert SSRF.resolve_host("example.com") == {:error, :restricted_address}
    end

    test "rejects a domain whose AAAA answer is a private/reserved address" do
      stub_dns(%{"example.com" => {[], [{0xFC00, 0, 0, 0, 0, 0, 0, 1}]}})

      assert SSRF.resolve_host("example.com") == {:error, :restricted_address}
    end

    test "rejects a domain when DNS returns a mix of public and private addresses" do
      stub_dns(%{"example.com" => {[{93, 184, 216, 34}, {169, 254, 169, 254}], []}})

      assert SSRF.resolve_host("example.com") == {:error, :restricted_address}
    end

    test "reports a domain with no A/AAAA records as unresolved" do
      stub_dns(%{"example.com" => {[], []}})

      assert SSRF.resolve_host("example.com") == {:error, :dns_resolution_failed}
    end
  end

  describe "get/2" do
    test "fetches a literal public IP host directly (no DNS lookup), pinning the Host header" do
      expect_no_dns_lookup()

      Req.Test.stub(__MODULE__, fn conn ->
        assert {"host", "93.184.216.34"} in conn.req_headers
        Plug.Conn.send_resp(conn, 200, "ok")
      end)

      assert {:ok, %Req.Response{status: 200, body: "ok"}} =
               SSRF.get("https://93.184.216.34/", plug: {Req.Test, __MODULE__})
    end

    test "refuses plain http" do
      expect_no_dns_lookup()

      assert SSRF.get("http://good.example/") == {:error, :invalid_url}
    end

    test "refuses a host whose DNS answer is a private address" do
      stub_dns(%{"evil.example" => {[{169, 254, 169, 254}], []}})

      assert SSRF.get("https://evil.example/") == {:error, :restricted_address}
    end
  end

  # Real HTTPS server on loopback. `SSRFIPCheck` allows only 127.0.0.1, so
  # every other address rule still applies.
  describe "get/2 against a local server" do
    TLSServer.setup_allow_loopback()

    test "resolves via DNS and sends the hostname in the Host header" do
      stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

      test_pid = self()

      {ca, port} =
        TLSServer.start(
          cert_host: "good.example",
          handler: fn conn, _port ->
            send(test_pid, {:host, Plug.Conn.get_req_header(conn, "host")})
            Plug.Conn.send_resp(conn, 200, "hello")
          end
        )

      assert {:ok, %Req.Response{status: 200, body: "hello"}} =
               get(ca, "https://good.example:#{port}/")

      assert_received {:host, ["good.example"]}
    end

    @tag :capture_log
    test "stops at total_timeout even while the server is still silent" do
      stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

      {ca, port} =
        TLSServer.start(
          cert_host: "good.example",
          handler: fn conn, _port ->
            Process.sleep(1_000)
            Plug.Conn.send_resp(conn, 200, "eventually")
          end
        )

      {microseconds, result} =
        :timer.tc(fn -> get(ca, "https://good.example:#{port}/", total_timeout: 200) end)

      assert result == {:error, :timeout}
      assert microseconds < 500_000
    end

    test "does not retry" do
      stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

      test_pid = self()

      {ca, port} =
        TLSServer.start(
          cert_host: "good.example",
          handler: fn conn, _port ->
            send(test_pid, :called)
            Plug.Conn.send_resp(conn, 503, "")
          end
        )

      assert {:ok, %Req.Response{status: 503}} = get(ca, "https://good.example:#{port}/")

      assert_received :called
      refute_received :called
    end

    test "follows no redirect" do
      stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})
      test_pid = self()

      for status <- [301, 302, 303, 307, 308] do
        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, port ->
              case conn.request_path do
                "/start" ->
                  conn
                  |> Plug.Conn.put_resp_header("location", "https://good.example:#{port}/final")
                  |> Plug.Conn.send_resp(status, "")

                "/final" ->
                  send(test_pid, :followed)
                  Plug.Conn.send_resp(conn, 200, "done")
              end
            end
          )

        assert get(ca, "https://good.example:#{port}/start") ==
                 {:error, :redirect_not_followed}
      end

      refute_received :followed
    end

    # Req would follow on either option, past the address checks.
    test "follows no redirect even when asked to" do
      stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})
      test_pid = self()

      {ca, port} =
        TLSServer.start(
          cert_host: "good.example",
          handler: fn conn, port ->
            case conn.request_path do
              "/start" ->
                conn
                |> Plug.Conn.put_resp_header("location", "https://good.example:#{port}/final")
                |> Plug.Conn.send_resp(302, "")

              "/final" ->
                send(test_pid, :followed)
                Plug.Conn.send_resp(conn, 200, "done")
            end
          end
        )

      for opt <- [follow_redirects: true, redirect: true] do
        assert get(ca, "https://good.example:#{port}/start", [opt]) ==
                 {:error, :redirect_not_followed}
      end

      refute_received :followed
    end

    test "returns a 3xx without a Location" do
      stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

      {ca, port} =
        TLSServer.start(
          cert_host: "good.example",
          handler: fn conn, _port -> Plug.Conn.send_resp(conn, 302, "body") end
        )

      assert {:ok, %Req.Response{status: 302, body: "body"}} =
               get(ca, "https://good.example:#{port}/")
    end
  end

  describe "certificate checks" do
    TLSServer.setup_allow_loopback()

    # Control: without it, the test below would pass on any connection failure.
    test "accepts a certificate issued for the requested hostname" do
      stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

      {ca, port} =
        TLSServer.start(
          cert_host: "good.example",
          handler: fn conn, _port -> Plug.Conn.send_resp(conn, 200, "ok") end
        )

      assert {:ok, %Req.Response{status: 200, body: "ok"}} =
               get(ca, "https://good.example:#{port}/")
    end

    test "refuses a certificate issued for another hostname" do
      stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

      {ca, port} =
        TLSServer.start(
          cert_host: "impostor.test",
          handler: fn conn, _port -> Plug.Conn.send_resp(conn, 200, "ok") end
        )

      assert {:error, %Req.TransportError{reason: {:tls_alert, {alert, _detail}}}} =
               get(ca, "https://good.example:#{port}/")

      assert alert in [:handshake_failure, :bad_certificate, :certificate_unknown]
    end
  end

  defp get(ca, url, opts \\ []) do
    SSRF.get(url, [cacerts: [ca]] ++ opts)
  end
end
