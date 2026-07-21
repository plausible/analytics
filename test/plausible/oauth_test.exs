defmodule Plausible.OAuthTest do
  use Plausible.DataCase, async: true

  alias Plausible.OAuth
  alias Plausible.OAuth.{AccessToken, AuthorizationCode, Token}

  @redirect_uri "https://client.example/callback"
  @client_id "https://client.example/oauth-metadata"
  @resource "https://plausible.example/mcp"

  defp verifier_and_challenge do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp code_attrs(challenge, overrides \\ %{}) do
    Map.merge(
      %{
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        code_challenge: challenge,
        code_challenge_method: "S256",
        scopes: ["stats:read:*", "sites:read:*"],
        resource: @resource
      },
      overrides
    )
  end

  describe "verify_pkce/3" do
    test "accepts a valid S256 verifier" do
      {verifier, challenge} = verifier_and_challenge()
      assert OAuth.verify_pkce(challenge, verifier, "S256") == :ok
    end

    test "rejects an incorrect verifier" do
      {_verifier, challenge} = verifier_and_challenge()
      assert OAuth.verify_pkce(challenge, "not-the-verifier", "S256") == {:error, :invalid_grant}
    end

    test "rejects the plain method even when values match" do
      {verifier, _challenge} = verifier_and_challenge()
      assert OAuth.verify_pkce(verifier, verifier, "plain") == {:error, :invalid_grant}
    end

    test "rejects missing verifier" do
      {_verifier, challenge} = verifier_and_challenge()
      assert OAuth.verify_pkce(challenge, nil, "S256") == {:error, :invalid_grant}
    end
  end

  describe "authorization codes" do
    setup do
      user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)
      {:ok, user: user, team: team}
    end

    test "create + consume round-trips and is single-use", %{user: user, team: team} do
      {verifier, challenge} = verifier_and_challenge()
      {:ok, raw} = OAuth.create_authorization_code(user, team, code_attrs(challenge))

      assert {:ok, %AuthorizationCode{} = code} =
               OAuth.consume_authorization_code(raw, verifier, @redirect_uri, @resource)

      assert code.user_id == user.id
      assert code.team_id == team.id
      assert code.scopes == ["stats:read:*", "sites:read:*"]

      # Second consumption fails - the code was deleted.
      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(raw, verifier, @redirect_uri, @resource)
    end

    test "rejects a bad PKCE verifier", %{user: user, team: team} do
      {_verifier, challenge} = verifier_and_challenge()
      {:ok, raw} = OAuth.create_authorization_code(user, team, code_attrs(challenge))

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(raw, "wrong", @redirect_uri, @resource)
    end

    test "rejects redirect_uri mismatch", %{user: user, team: team} do
      {verifier, challenge} = verifier_and_challenge()
      {:ok, raw} = OAuth.create_authorization_code(user, team, code_attrs(challenge))

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(
                 raw,
                 verifier,
                 "https://evil.example/cb",
                 @resource
               )
    end

    test "rejects resource mismatch", %{user: user, team: team} do
      {verifier, challenge} = verifier_and_challenge()
      {:ok, raw} = OAuth.create_authorization_code(user, team, code_attrs(challenge))

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(raw, verifier, @redirect_uri, "https://evil/mcp")
    end

    test "rejects an expired code", %{user: user, team: team} do
      {verifier, challenge} = verifier_and_challenge()
      code = Token.generate(:code)

      Repo.insert!(
        AuthorizationCode.changeset(%{
          code_hash: code.hash,
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          code_challenge: challenge,
          code_challenge_method: "S256",
          scopes: ["stats:read:*"],
          resource: @resource,
          user_id: user.id,
          team_id: team.id,
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })
      )

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code.raw, verifier, @redirect_uri, @resource)
    end
  end

  describe "tokens" do
    setup do
      user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)
      {verifier, challenge} = verifier_and_challenge()
      {:ok, raw} = OAuth.create_authorization_code(user, team, code_attrs(challenge))
      {:ok, code} = OAuth.consume_authorization_code(raw, verifier, @redirect_uri, @resource)
      {:ok, tokens} = OAuth.issue_tokens(code)
      {:ok, user: user, team: team, tokens: tokens}
    end

    test "issue_tokens returns a standard token response", %{tokens: tokens} do
      assert tokens.token_type == "Bearer"
      assert tokens.expires_in == OAuth.access_token_ttl()
      assert is_binary(tokens.access_token)
      assert is_binary(tokens.refresh_token)
      assert tokens.scope == "stats:read:* sites:read:*"
    end

    test "find_access_token resolves a valid token with preloads", %{
      tokens: tokens,
      user: user,
      team: team
    } do
      assert {:ok, token} = OAuth.find_access_token(tokens.access_token)
      assert token.user.id == user.id
      assert token.team.id == team.id
    end

    test "refresh rotates the pair and invalidates the old tokens", %{tokens: tokens} do
      assert {:ok, new_tokens} = OAuth.refresh_tokens(tokens.refresh_token)
      refute new_tokens.access_token == tokens.access_token
      refute new_tokens.refresh_token == tokens.refresh_token

      # Old refresh token can't be reused.
      assert {:error, :invalid_grant} = OAuth.refresh_tokens(tokens.refresh_token)
      # Old access token no longer resolves.
      assert {:error, :invalid_token} = OAuth.find_access_token(tokens.access_token)
      # New access token works.
      assert {:ok, _} = OAuth.find_access_token(new_tokens.access_token)
    end

    test "find_access_token rejects expired tokens", %{user: user, team: team} do
      access = Token.generate(:access)

      Repo.insert!(
        AccessToken.changeset(%{
          access_token_hash: access.hash,
          access_token_prefix: access.prefix,
          client_id: @client_id,
          scopes: ["stats:read:*"],
          user_id: user.id,
          team_id: team.id,
          access_token_expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })
      )

      assert {:error, :invalid_token} = OAuth.find_access_token(access.raw)
    end
  end

  describe "fetch_client_metadata/1" do
    test "rejects non-HTTPS client_id" do
      assert OAuth.fetch_client_metadata("http://client.example/meta") ==
               {:error, :client_id_not_https}
    end

    test "fails closed when no SSRF-safe fetcher is configured" do
      # No :client_metadata_fetcher configured by default.
      assert OAuth.fetch_client_metadata(@client_id) == {:error, :client_fetch_unavailable}
    end

    test "validates a self-referential document with a configured fetcher" do
      with_fetcher(fn url ->
        {:ok,
         Jason.encode!(%{
           "client_id" => url,
           "redirect_uris" => [@redirect_uri],
           "client_name" => "Test Client"
         })}
      end)

      assert {:ok, doc} = OAuth.fetch_client_metadata(@client_id)
      assert doc["client_id"] == @client_id
      assert doc["redirect_uris"] == [@redirect_uri]
    end

    test "rejects a document whose client_id does not match the URL" do
      with_fetcher(fn _url ->
        {:ok,
         Jason.encode!(%{"client_id" => "https://other", "redirect_uris" => [@redirect_uri]})}
      end)

      assert OAuth.fetch_client_metadata(@client_id) == {:error, :client_id_mismatch}
    end

    test "rejects a document without redirect_uris" do
      with_fetcher(fn url ->
        {:ok, Jason.encode!(%{"client_id" => url})}
      end)

      assert OAuth.fetch_client_metadata(@client_id) == {:error, :missing_redirect_uris}
    end
  end

  describe "redirect_uri_registered?/2" do
    test "requires an exact match for non-loopback URIs" do
      registered = ["https://client.example/cb"]
      assert OAuth.redirect_uri_registered?("https://client.example/cb", registered)
      refute OAuth.redirect_uri_registered?("https://client.example/other", registered)
      refute OAuth.redirect_uri_registered?("https://evil.example/cb", registered)
    end

    test "matches loopback URIs ignoring the port (RFC 8252)" do
      # Claude Code declares these and connects on an ephemeral port.
      registered = ["http://localhost/callback", "http://127.0.0.1/callback"]

      assert OAuth.redirect_uri_registered?("http://localhost:3118/callback", registered)
      assert OAuth.redirect_uri_registered?("http://127.0.0.1:52001/callback", registered)
    end

    test "loopback match still enforces scheme, host and path" do
      registered = ["http://localhost/callback"]

      refute OAuth.redirect_uri_registered?("https://localhost:3000/callback", registered)
      refute OAuth.redirect_uri_registered?("http://localhost:3000/evil", registered)
      # Host must match: a public host is never treated as loopback.
      refute OAuth.redirect_uri_registered?("http://evil.example:3000/callback", registered)
    end

    test "handles nil" do
      refute OAuth.redirect_uri_registered?(nil, ["http://localhost/callback"])
    end
  end

  describe "delete_expired/0" do
    test "purges expired codes and fully-expired tokens" do
      user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)
      now = DateTime.utc_now()

      expired_code = Token.generate(:code)

      Repo.insert!(
        AuthorizationCode.changeset(%{
          code_hash: expired_code.hash,
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          code_challenge: "x",
          code_challenge_method: "S256",
          user_id: user.id,
          team_id: team.id,
          expires_at: DateTime.add(now, -60, :second)
        })
      )

      expired_token = Token.generate(:access)

      Repo.insert!(
        AccessToken.changeset(%{
          access_token_hash: expired_token.hash,
          access_token_prefix: expired_token.prefix,
          client_id: @client_id,
          user_id: user.id,
          team_id: team.id,
          access_token_expires_at: DateTime.add(now, -120, :second),
          refresh_token_expires_at: DateTime.add(now, -60, :second)
        })
      )

      assert %{authorization_codes: codes, access_tokens: tokens} = OAuth.delete_expired()
      assert codes >= 1
      assert tokens >= 1
      assert Repo.aggregate(AuthorizationCode, :count) == 0
      assert Repo.aggregate(AccessToken, :count) == 0
    end
  end

  defp with_fetcher(fun) do
    Application.put_env(:plausible, Plausible.OAuth, client_metadata_fetcher: fun)
    on_exit(fn -> Application.delete_env(:plausible, Plausible.OAuth) end)
  end
end
