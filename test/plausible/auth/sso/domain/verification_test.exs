defmodule Plausible.Auth.SSO.Domain.VerificationTest do
  # Not async: patches the global address check and Verification's req_opts.
  use Plausible.DataCase, async: false

  @moduletag :ee_only

  on_ee do
    use Plausible.Test.Support.DNS

    alias Plasusible.Test.Support.DNSServer
    alias Plausible.Auth.SSO.Domain.Verification
    alias Plausible.Test.Support.TLSServer

    require TLSServer
    alias Plug.Conn

    # Requests go through Plausible.SSRF. The port rides along in the domain,
    # since the test server can't listen on 443.
    TLSServer.setup_allow_loopback()

    @meta_tag ~s|<html><meta name="plausible-sso-verification" content="ex4mpl3"/></html>|

    describe "dns_txt/3" do
      test "verifies a domain with the TXT record" do
        {:ok, port} = DNSServer.start("plausible-sso-verification=ex4mpl3")

        refute Verification.dns_txt("example.com", "failing-identifier",
                 nameservers: [{{0, 0, 0, 0}, port}]
               )

        assert Verification.dns_txt("example.com", "ex4mpl3", nameservers: [{{0, 0, 0, 0}, port}])
      end
    end

    describe "url/3" do
      test "verifies a domain serving the identifier over https" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, _port ->
              case conn.request_path do
                "/plausible-sso-verification" -> Conn.send_resp(conn, 200, "ex4mpl3")
              end
            end
          )

        patch_trusted_certs(ca)

        assert Verification.url("good.example:#{port}", "ex4mpl3")
        refute Verification.url("good.example:#{port}", "failing-identifier")
      end

      test "fails when DNS resolves to a private address" do
        expect_dns_lookup("example.com", [{192, 168, 1, 1}])

        refute Verification.url("example.com", "ex4mpl3")
      end

      # Not even within the domain: sites that redirect verify with DNS TXT.
      test "does not follow redirects, even to the same domain or a subdomain" do
        test_pid = self()

        stub_dns(%{
          "good.example" => {[{127, 0, 0, 1}], []},
          "www.good.example" => {[{127, 0, 0, 1}], []}
        })

        for target <- ["good.example", "www.good.example"] do
          {ca, port} =
            TLSServer.start(
              cert_host: ["good.example", "www.good.example"],
              handler: fn conn, port ->
                case conn.request_path do
                  "/plausible-sso-verification" ->
                    conn
                    |> Conn.put_resp_header("location", "https://#{target}:#{port}/moved")
                    |> Conn.send_resp(301, "")

                  "/moved" ->
                    send(test_pid, {:followed, target})
                    Conn.send_resp(conn, 200, "ex4mpl3")
                end
              end
            )

          patch_trusted_certs(ca)

          refute Verification.url("good.example:#{port}", "ex4mpl3")
          refute_received {:followed, ^target}
        end
      end

      test "fails on a certificate issued for another hostname" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        {ca, port} =
          TLSServer.start(
            cert_host: "impostor.test",
            handler: fn conn, _port -> Conn.send_resp(conn, 200, "ex4mpl3") end
          )

        patch_trusted_certs(ca)

        refute Verification.url("good.example:#{port}", "ex4mpl3")
      end

      test "fails when redirected to plain http, even if it would match" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        test_pid = self()
        bypass = Bypass.open()

        Bypass.stub(bypass, "GET", "/plausible-sso-verification", fn conn ->
          send(test_pid, :plain_http_fetched)
          Conn.resp(conn, 200, "ex4mpl3")
        end)

        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, _port ->
              conn
              |> Conn.put_resp_header(
                "location",
                "http://good.example:#{bypass.port}/plausible-sso-verification"
              )
              |> Conn.send_resp(302, "")
            end
          )

        patch_trusted_certs(ca)

        refute Verification.url("good.example:#{port}", "ex4mpl3")
        refute_received :plain_http_fetched
      end

      test "does not retry" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        test_pid = self()

        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, _port ->
              send(test_pid, :called)
              Conn.send_resp(conn, 503, "")
            end
          )

        patch_trusted_certs(ca)

        refute Verification.url("good.example:#{port}", "ex4mpl3")

        assert_received :called
        refute_received :called
      end
    end

    describe "meta_tag/3" do
      test "verifies a domain serving the meta tag over https" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, _port ->
              case conn.request_path do
                "/" ->
                  conn
                  |> Conn.put_resp_header("content-type", "text/html")
                  |> Conn.send_resp(200, @meta_tag)
              end
            end
          )

        patch_trusted_certs(ca)

        assert Verification.meta_tag("good.example:#{port}", "ex4mpl3")
        refute Verification.meta_tag("good.example:#{port}", "failing-identifier")
      end

      test "fails on non-html" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, _port -> Conn.send_resp(conn, 200, @meta_tag) end
          )

        patch_trusted_certs(ca)

        refute Verification.meta_tag("good.example:#{port}", "ex4mpl3")
      end

      test "fails on parse failure" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, _port ->
              conn
              |> Conn.put_resp_header("content-type", "text/html")
              |> Conn.send_resp(200, ~s|meta name="plausible-sso-verification" content="ex4mpl3|)
            end
          )

        patch_trusted_certs(ca)

        refute Verification.meta_tag("good.example:#{port}", "ex4mpl3")
      end

      test "succeeds in case of multiple matches" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, _port ->
              conn
              |> Conn.put_resp_header("content-type", "text/html")
              |> Conn.send_resp(200, """
              <html>
              <meta name="plausible-sso-verification" content="ex4mpl3"/>
              <meta name="plausible-sso-verification" content="ex4mpl3"/>
              </html>
              """)
            end
          )

        patch_trusted_certs(ca)

        assert Verification.meta_tag("good.example:#{port}", "ex4mpl3")
      end

      test "does not follow the domain to its www subdomain" do
        test_pid = self()

        stub_dns(%{
          "good.example" => {[{127, 0, 0, 1}], []},
          "www.good.example" => {[{127, 0, 0, 1}], []}
        })

        {ca, port} =
          TLSServer.start(
            cert_host: ["good.example", "www.good.example"],
            handler: fn conn, port ->
              case conn.host do
                "good.example" ->
                  conn
                  |> Conn.put_resp_header("location", "https://www.good.example:#{port}/")
                  |> Conn.send_resp(301, "")

                "www.good.example" ->
                  send(test_pid, :followed)

                  conn
                  |> Conn.put_resp_header("content-type", "text/html")
                  |> Conn.send_resp(200, @meta_tag)
              end
            end
          )

        patch_trusted_certs(ca)

        refute Verification.meta_tag("good.example:#{port}", "ex4mpl3")
        refute_received :followed
      end
    end

    describe "run/3" do
      test "DNS matches, no HTTP endpoint is ever called" do
        {:ok, dns_port} = DNSServer.start("plausible-sso-verification=ex4mpl3")
        expect_no_dns_lookup()

        assert {:ok, :dns_txt} =
                 Verification.run("good.example", "ex4mpl3",
                   nameservers: [{{0, 0, 0, 0}, dns_port}]
                 )
      end

      test "DNS fails to match, url check succeeds" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        {:ok, dns_port} = DNSServer.start("plausible-sso-verification=something-else")

        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, _port ->
              case conn.request_path do
                "/plausible-sso-verification" -> Conn.send_resp(conn, 200, "ex4mpl3")
              end
            end
          )

        patch_trusted_certs(ca)

        assert {:ok, :url} =
                 Verification.run("good.example:#{port}", "ex4mpl3",
                   nameservers: [{{0, 0, 0, 0}, dns_port}]
                 )
      end

      test "DNS and url checks fail to match, meta tag check succeeds" do
        stub_dns(%{"good.example" => {[{127, 0, 0, 1}], []}})

        {:ok, dns_port} = DNSServer.start("plausible-sso-verification=something-else")

        {ca, port} =
          TLSServer.start(
            cert_host: "good.example",
            handler: fn conn, _port ->
              case conn.request_path do
                "/plausible-sso-verification" ->
                  Conn.send_resp(conn, 404, "")

                "/" ->
                  conn
                  |> Conn.put_resp_header("content-type", "text/html")
                  |> Conn.send_resp(200, @meta_tag)
              end
            end
          )

        patch_trusted_certs(ca)

        assert {:ok, :meta_tag} =
                 Verification.run("good.example:#{port}", "ex4mpl3",
                   nameservers: [{{0, 0, 0, 0}, dns_port}]
                 )
      end
    end

    defp patch_trusted_certs(ca), do: patch_env(Verification, req_opts: [cacerts: [ca]])
  end
end
