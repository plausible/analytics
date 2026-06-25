defmodule Plausible.Auth.SSO.Domain.VerificationTest do
  use Plausible.DataCase, async: true

  @moduletag :ee_only

  on_ee do
    use Plausible.Test.Support.DNS

    alias Plasusible.Test.Support.DNSServer
    alias Plausible.Auth.SSO.Domain.Verification
    alias Plug.Conn

    setup do
      team = new_site().team
      bypass = Bypass.open()

      {:ok, team: team, bypass: bypass}
    end

    describe "individual checks" do
      test "dns_txt" do
        {:ok, port} = DNSServer.start("plausible-sso-verification=ex4mpl3")

        refute Verification.dns_txt("example.com", "failing-identifier",
                 nameservers: [{{0, 0, 0, 0}, port}]
               )

        assert Verification.dns_txt("example.com", "ex4mpl3", nameservers: [{{0, 0, 0, 0}, port}])
      end

      test "url", %{bypass: bypass} do
        Bypass.expect(bypass, "GET", "/test", fn conn ->
          Conn.resp(conn, 200, "ex4mpl3")
        end)

        refute Verification.url("example.com", "failing-identifier",
                 url_override: "http://localhost:#{bypass.port}/test"
               )

        assert Verification.url("example.com", "ex4mpl3",
                 url_override: "http://localhost:#{bypass.port}/test"
               )
      end

      test "meta_tag", %{bypass: bypass} do
        Bypass.expect(bypass, "GET", "/test", fn conn ->
          conn
          |> Conn.put_resp_header("content-type", "text/html")
          |> Conn.resp(200, """
            <html>
            <meta name="plausible-sso-verification" content="ex4mpl3"/>
            </html>
          """)
        end)

        refute Verification.meta_tag("example.com", "failing-identifier",
                 url_override: "http://localhost:#{bypass.port}/test"
               )

        assert Verification.meta_tag("example.com", "ex4mpl3",
                 url_override: "http://localhost:#{bypass.port}/test"
               )
      end

      test "meta-tag fails on non-html", %{bypass: bypass} do
        Bypass.expect_once(bypass, "GET", "/test", fn conn ->
          Conn.resp(conn, 200, """
          <html>
          <meta name="plausible-sso-verification" content="ex4mpl3"/>
          </html>
          """)
        end)

        refute Verification.meta_tag("example.com", "ex4mpl3",
                 url_override: "http://localhost:#{bypass.port}/test"
               )
      end

      test "meta-tag fails on parse failure", %{bypass: bypass} do
        Bypass.expect_once(bypass, "GET", "/test", fn conn ->
          conn
          |> Conn.put_resp_header("content-type", "text/html")
          |> Conn.resp(200, """
          meta name="plausible-sso-verification" content="ex4mpl3
          """)
        end)

        refute Verification.meta_tag("example.com", "ex4mpl3",
                 url_override: "http://localhost:#{bypass.port}/test"
               )
      end

      test "url refuses to request a domain resolving to an internal IP (SSRF)" do
        stub_lookup_a_records("internal.attacker.example", [{169, 254, 169, 254}])

        refute Verification.url("internal.attacker.example", "ex4mpl3")
      end

      test "meta_tag refuses to request a domain resolving to an internal IP (SSRF)" do
        stub_lookup_a_records("internal.attacker.example", [{10, 0, 0, 1}])

        refute Verification.meta_tag("internal.attacker.example", "ex4mpl3")
      end

      test "url refuses a domain whose AAAA record is internal (SSRF)" do
        stub_lookup_a_records(
          "dualstack.attacker.example",
          [{93, 184, 216, 34}],
          [{0, 0, 0, 0, 0, 0, 0, 1}]
        )

        refute Verification.url("dualstack.attacker.example", "ex4mpl3")
      end

      test "url refuses to follow a redirect to an internal host (SSRF)", %{bypass: bypass} do
        Bypass.expect(bypass, "GET", "/test", fn conn ->
          conn
          |> Conn.put_resp_header("location", "http://10.0.0.1/")
          |> Conn.resp(302, "")
        end)

        refute Verification.url("example.com", "ex4mpl3",
                 url_override: "http://localhost:#{bypass.port}/test"
               )
      end

      test "url still follows a redirect to a public host", %{bypass: bypass} do
        # The SSRF guard resolves redirect targets; stub the host (still hit by
        # Finch's own resolution to reach Bypass) to a public address.
        stub_lookup_a_records("localhost", [{93, 184, 216, 34}])

        Bypass.expect(bypass, "GET", "/redirect", fn conn ->
          conn
          |> Conn.put_resp_header("location", "/verified")
          |> Conn.resp(302, "")
        end)

        Bypass.expect(bypass, "GET", "/verified", fn conn ->
          Conn.resp(conn, 200, "ex4mpl3")
        end)

        assert Verification.url("example.com", "ex4mpl3",
                 url_override: "http://localhost:#{bypass.port}/redirect"
               )
      end

      test "meta_tag succeeds in case of multiple matches", %{bypass: bypass} do
        Bypass.expect(bypass, "GET", "/test", fn conn ->
          conn
          |> Conn.put_resp_header("content-type", "text/html")
          |> Conn.resp(200, """
          <html>
          <meta name="plausible-sso-verification" content="ex4mpl3"/>
          <meta name="plausible-sso-verification" content="ex4mpl3"/>
          </html>
          """)
        end)

        assert Verification.meta_tag("example.com", "ex4mpl3",
                 url_override: "http://localhost:#{bypass.port}/test"
               )
      end
    end

    describe "all methods" do
      test "DNS matches, no HTTP endpoint is ever called", %{bypass: bypass} do
        {:ok, dns_port} = DNSServer.start("plausible-sso-verification=ex4mpl3")

        Bypass.stub(bypass, "GET", "/", fn _conn -> raise "should never be called" end)

        assert {:ok, :dns_txt} =
                 Verification.run("example.com", "ex4mpl3",
                   url_override: "http://localhost:#{bypass.port}/",
                   nameservers: [{{0, 0, 0, 0}, dns_port}]
                 )
      end

      test "DNS fails to match, url check succeeds", %{bypass: bypass} do
        Bypass.expect_once(bypass, "GET", "/", fn conn ->
          Conn.resp(conn, 200, "ex4mpl3")
        end)

        assert {:ok, :url} =
                 Verification.run("example.com", "ex4mpl3",
                   url_override: "http://localhost:#{bypass.port}/"
                 )
      end

      test "DNS and url checks fail to match, meta tag check succeeds", %{bypass: bypass} do
        Bypass.expect(bypass, "GET", "/", fn conn ->
          conn
          |> Conn.put_resp_header("content-type", "text/html")
          |> Conn.resp(
            200,
            "<html><meta name=\"plausible-sso-verification\" content=\"ex4mpl3\"/></html>"
          )
        end)

        assert {:ok, :meta_tag} =
                 Verification.run("example.com", "ex4mpl3",
                   url_override: "http://localhost:#{bypass.port}/"
                 )
      end
    end
  end
end
