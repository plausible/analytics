defmodule Plausible.SSRFTest do
  use ExUnit.Case, async: true
  use Plausible.TestUtils
  use Plausible.Test.Support.DNS

  alias Plausible.SSRF

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
               SSRF.get("http://93.184.216.34/", plug: {Req.Test, __MODULE__})
    end

    test "resolves via DNS, fetches, and pins the Host header to the original hostname" do
      stub_dns(%{"good.example" => {[{93, 184, 216, 34}], []}})

      Req.Test.stub(__MODULE__, fn conn ->
        assert {"host", "good.example"} in conn.req_headers
        Plug.Conn.send_resp(conn, 200, "hello")
      end)

      assert {:ok, %Req.Response{status: 200, body: "hello"}} =
               SSRF.get("http://good.example/", plug: {Req.Test, __MODULE__})
    end

    test "rejects a host whose DNS answer is a private address, without ever reaching the plug" do
      stub_dns(%{"evil.example" => {[{127, 0, 0, 1}], []}})

      Req.Test.stub(__MODULE__, fn _conn ->
        raise "should never be called"
      end)

      assert SSRF.get("http://evil.example/", plug: {Req.Test, __MODULE__}) ==
               {:error, :restricted_address}
    end

    test "follows a redirect to a still-public host, re-validating before following" do
      stub_dns(%{
        "good.example" => {[{93, 184, 216, 34}], []},
        "still-good.example" => {[{93, 184, 216, 35}], []}
      })

      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/start" ->
            conn
            |> Plug.Conn.put_resp_header("location", "http://still-good.example/final")
            |> Plug.Conn.send_resp(302, "")

          "/final" ->
            Plug.Conn.send_resp(conn, 200, "done")
        end
      end)

      assert {:ok, %Req.Response{status: 200, body: "done"}} =
               SSRF.get("http://good.example/start", plug: {Req.Test, __MODULE__})
    end

    test "rejects a redirect to a host whose DNS answer is a private address" do
      stub_dns(%{
        "good.example" => {[{93, 184, 216, 34}], []},
        "internal.example" => {[{169, 254, 169, 254}], []}
      })

      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/start" ->
            conn
            |> Plug.Conn.put_resp_header("location", "http://internal.example/steal-secrets")
            |> Plug.Conn.send_resp(302, "")

          "/steal-secrets" ->
            raise "should never be called - redirect target must be rejected before follow-up"
        end
      end)

      assert SSRF.get("http://good.example/start", plug: {Req.Test, __MODULE__}) ==
               {:error, :restricted_address}
    end

    test "gives up after exceeding the redirect budget" do
      stub_dns(%{"loopy.example" => {[{93, 184, 216, 34}], []}})

      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://loopy.example/")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert SSRF.get("http://loopy.example/", plug: {Req.Test, __MODULE__}, max_redirects: 2) ==
               {:error, :too_many_redirects}
    end
  end

  describe "pool_max_idle_time" do
    test "an idle Finch pool is reaped after pool_max_idle_time, instead of lingering forever" do
      # This exercises the same connect_options/pool_max_idle_time shape
      # SSRF.do_request/3 builds, via a real Finch pool - it can't be driven
      # through SSRF.get/2 itself because the only network target reachable
      # from a test is loopback, which SSRF.resolve_host/1 correctly (and
      # by design) rejects as a restricted address.
      test_pid = self()
      bypass = Bypass.open()

      handler_id = "ssrf-pool-idle-test-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:finch, :pool_max_idle_time_exceeded],
        fn _event, _measurements, metadata, _config ->
          if metadata.port == bypass.port, do: send(test_pid, :pool_reaped)
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      Bypass.expect_once(bypass, "GET", "/", fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end)

      assert {:ok, %Req.Response{status: 200}} =
               Req.request(
                 method: :get,
                 url: "http://localhost:#{bypass.port}/",
                 connect_options: [hostname: "localhost"],
                 pool_max_idle_time: 50
               )

      assert_receive :pool_reaped
    end
  end
end
