defmodule Plausible.Auth.SSO.Domain.VerificationTest do
  use Plausible.DataCase, async: true

  @moduletag :ee_only

  on_ee do
    use Plausible.Test.Support.DNS

    alias Plasusible.Test.Support.DNSServer
    alias Plausible.Auth.SSO.Domain.Verification
    alias Plug.Conn

    # Without a matching expectation, a request to the plug raises.
    setup {Req.Test, :verify_on_exit!}

    @meta_tag ~s|<html><meta name="plausible-sso-verification" content="ex4mpl3"/></html>|

    describe "individual checks" do
      test "dns_txt" do
        {:ok, port} = DNSServer.start("plausible-sso-verification=ex4mpl3")

        refute Verification.dns_txt("example.com", "failing-identifier",
                 nameservers: [{{0, 0, 0, 0}, port}]
               )

        assert Verification.dns_txt("example.com", "ex4mpl3", nameservers: [{{0, 0, 0, 0}, port}])
      end

      test "url" do
        stub_dns()

        serve(2, fn conn ->
          assert conn.scheme == :https
          assert conn.host == "93.184.216.34"
          assert Conn.get_req_header(conn, "host") == ["example.com"]
          assert conn.request_path == "/plausible-sso-verification"

          Conn.send_resp(conn, 200, "ex4mpl3")
        end)

        refute Verification.url("example.com", "failing-identifier")
        assert Verification.url("example.com", "ex4mpl3")
      end

      test "url is protected against SSRF when DNS resolves to a private IP" do
        expect_dns_lookup("example.com", [{192, 168, 1, 1}])

        refute Verification.url("example.com", "ex4mpl3")
      end

      test "meta_tag" do
        stub_dns()

        serve(2, fn conn ->
          refute conn.request_path == "/plausible-sso-verification"

          conn
          |> Conn.put_resp_header("content-type", "text/html")
          |> Conn.send_resp(200, @meta_tag)
        end)

        refute Verification.meta_tag("example.com", "failing-identifier")
        assert Verification.meta_tag("example.com", "ex4mpl3")
      end

      test "meta_tag is protected against SSRF when DNS resolves to a private IP" do
        expect_dns_lookup("example.com", [{192, 168, 1, 1}])

        refute Verification.meta_tag("example.com", "ex4mpl3")
      end

      test "meta-tag fails on non-html" do
        stub_dns()
        serve(fn conn -> Conn.send_resp(conn, 200, @meta_tag) end)

        refute Verification.meta_tag("example.com", "ex4mpl3")
      end

      test "meta-tag fails on parse failure" do
        stub_dns()

        serve(fn conn ->
          conn
          |> Conn.put_resp_header("content-type", "text/html")
          |> Conn.send_resp(200, """
          meta name="plausible-sso-verification" content="ex4mpl3
          """)
        end)

        refute Verification.meta_tag("example.com", "ex4mpl3")
      end

      test "meta_tag succeeds in case of multiple matches" do
        stub_dns()

        serve(fn conn ->
          conn
          |> Conn.put_resp_header("content-type", "text/html")
          |> Conn.send_resp(200, """
          <html>
          <meta name="plausible-sso-verification" content="ex4mpl3"/>
          <meta name="plausible-sso-verification" content="ex4mpl3"/>
          </html>
          """)
        end)

        assert Verification.meta_tag("example.com", "ex4mpl3")
      end
    end

    describe "all methods" do
      test "DNS matches, no HTTP endpoint is ever called" do
        {:ok, dns_port} = DNSServer.start("plausible-sso-verification=ex4mpl3")
        expect_no_dns_lookup()

        assert {:ok, :dns_txt} =
                 Verification.run("example.com", "ex4mpl3",
                   nameservers: [{{0, 0, 0, 0}, dns_port}]
                 )
      end

      test "DNS fails to match, url check succeeds" do
        {:ok, dns_port} = DNSServer.start("plausible-sso-verification=something-else")
        stub_dns()

        serve(fn conn ->
          case conn.request_path do
            "/plausible-sso-verification" -> Conn.send_resp(conn, 200, "ex4mpl3")
          end
        end)

        assert {:ok, :url} =
                 Verification.run("example.com", "ex4mpl3",
                   nameservers: [{{0, 0, 0, 0}, dns_port}]
                 )
      end

      test "DNS and url checks fail to match, meta tag check succeeds" do
        {:ok, dns_port} = DNSServer.start("plausible-sso-verification=something-else")
        stub_dns()

        serve(2, fn conn ->
          case conn.request_path do
            "/plausible-sso-verification" ->
              Conn.send_resp(conn, 404, "")

            _ ->
              conn
              |> Conn.put_resp_header("content-type", "text/html")
              |> Conn.send_resp(200, @meta_tag)
          end
        end)

        assert {:ok, :meta_tag} =
                 Verification.run("example.com", "ex4mpl3",
                   nameservers: [{{0, 0, 0, 0}, dns_port}]
                 )
      end
    end

    defp serve(times \\ 1, fun), do: Req.Test.expect(Verification, times, fun)
  end
end
