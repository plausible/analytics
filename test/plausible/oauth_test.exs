defmodule Plausible.OAuthTest do
  use Plausible.DataCase, async: true
  use Plausible.Test.Support.DNS

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

    test "refuses to create a code without a team", %{user: user} do
      {_verifier, challenge} = verifier_and_challenge()

      assert {:error, changeset} =
               OAuth.create_authorization_code(user, nil, code_attrs(challenge))

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :team_id)
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

    test "client_name propagates from the authorization code to the grant", %{
      user: user,
      team: team
    } do
      {verifier, challenge} = verifier_and_challenge()
      attrs = code_attrs(challenge, %{client_name: "Claude Code"})

      {:ok, raw} = OAuth.create_authorization_code(user, team, attrs)
      {:ok, code} = OAuth.consume_authorization_code(raw, verifier, @redirect_uri, @resource)
      assert code.client_name == "Claude Code"

      {:ok, _tokens} = OAuth.issue_tokens(code)
      assert [grant] = OAuth.list_grants(user)
      assert grant.client_name == "Claude Code"
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

  describe "grants management" do
    setup do
      user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)
      {:ok, user: user, team: team}
    end

    defp insert_token(user, team, opts) do
      access = Token.generate(:access)
      now = DateTime.utc_now()

      Repo.insert!(
        AccessToken.changeset(%{
          access_token_hash: access.hash,
          access_token_prefix: access.prefix,
          refresh_token_hash: Token.generate(:refresh).hash,
          refresh_token_prefix: "plausible-mcp-rt-x",
          client_id: Keyword.get(opts, :client_id, @client_id),
          scopes: ["stats:read:*"],
          user_id: user.id,
          team_id: team.id,
          access_token_expires_at:
            Keyword.get(opts, :access_expires_at, DateTime.add(now, 3600, :second)),
          refresh_token_expires_at:
            Keyword.get(opts, :refresh_expires_at, DateTime.add(now, 86_400, :second))
        })
      )
    end

    test "list_grants returns usable grants, newest first, excluding fully-expired", %{
      user: user,
      team: team
    } do
      now = DateTime.utc_now()

      _expired =
        insert_token(user, team,
          access_expires_at: DateTime.add(now, -120, :second),
          refresh_expires_at: DateTime.add(now, -60, :second)
        )

      active = insert_token(user, team, client_id: "https://client.example/active")

      # A grant whose access token expired but refresh is still valid is still usable.
      refreshable =
        insert_token(user, team,
          client_id: "https://client.example/refreshable",
          access_expires_at: DateTime.add(now, -60, :second)
        )

      grants = OAuth.list_grants(user)
      ids = Enum.map(grants, & &1.id)

      assert active.id in ids
      assert refreshable.id in ids
      assert length(grants) == 2
      assert Enum.all?(grants, &Ecto.assoc_loaded?(&1.team))
    end

    test "list_grants is scoped to the user", %{user: user, team: team} do
      other = new_user()
      {:ok, other_team} = Plausible.Teams.get_or_create(other)
      insert_token(other, other_team, [])

      grant = insert_token(user, team, [])

      assert Enum.map(OAuth.list_grants(user), & &1.id) == [grant.id]
    end

    test "revoke_grant deletes the row and is user-scoped", %{user: user, team: team} do
      grant = insert_token(user, team, [])

      assert :ok = OAuth.revoke_grant(user, grant.id)
      assert OAuth.list_grants(user) == []
      # Already gone.
      assert {:error, :not_found} = OAuth.revoke_grant(user, grant.id)
    end

    test "revoke_grant won't delete another user's grant", %{user: user, team: team} do
      other = new_user()
      grant = insert_token(user, team, [])

      assert {:error, :not_found} = OAuth.revoke_grant(other, grant.id)
      assert [_] = OAuth.list_grants(user)
    end

    test "revoke_grants_for_team_member deletes only that user+team's grants", %{
      user: user,
      team: team
    } do
      other_user = new_user()
      {:ok, other_team} = Plausible.Teams.get_or_create(other_user)

      kept_other_user = insert_token(other_user, other_team, [])
      # Same user, but a different team - must be kept.
      kept_other_team = insert_token(user, other_team, [])
      _revoked_1 = insert_token(user, team, [])
      _revoked_2 = insert_token(user, team, [])

      assert 2 = OAuth.revoke_grants_for_team_member(user, team)

      remaining = Repo.all(AccessToken) |> Enum.map(& &1.id) |> Enum.sort()
      assert remaining == Enum.sort([kept_other_user.id, kept_other_team.id])
    end

    test "grants are cascade-deleted at the DB level when the user is deleted", %{
      user: user,
      team: team
    } do
      insert_token(user, team, [])
      assert Repo.aggregate(AccessToken, :count) == 1

      # Account deletion doesn't go through the team-membership removal path, but
      # the `on_delete: :delete_all` FK on user_id guarantees the grant is purged.
      assert {:ok, :deleted} = Plausible.Auth.delete_user(user)
      assert Repo.aggregate(AccessToken, :count) == 0
    end

    test "grants are cascade-deleted at the DB level when the team is deleted", %{team: team} do
      # Use a separate owner so deleting the team doesn't also delete our user.
      user = new_user()
      insert_token(user, team, [])
      assert Repo.aggregate(AccessToken, :count) == 1

      Repo.delete!(team)
      assert Repo.aggregate(AccessToken, :count) == 0
    end

    test "mark_used stamps last_used_at and throttles subsequent writes", %{
      user: user,
      team: team
    } do
      token = insert_token(user, team, [])
      assert is_nil(token.last_used_at)

      assert :ok = OAuth.mark_used(token)
      t1 = Repo.reload!(token).last_used_at
      assert t1

      # Second call within the throttle window doesn't move the timestamp.
      assert :ok = OAuth.mark_used(token)
      t2 = Repo.reload!(token).last_used_at
      assert t2 == t1
    end
  end

  describe "fetch_client_metadata/1" do
    test "rejects non-HTTPS client_id" do
      assert OAuth.fetch_client_metadata("http://client.example/meta") ==
               {:error, :client_id_not_https}
    end

    test "uses the SSRF-safe client and rejects restricted addresses" do
      # No :client_metadata_fetcher override -> the real Plausible.SSRF client is
      # used. Resolve the client_id host to a private address; SSRF must refuse to
      # connect before any request is made.
      stub_dns(%{"client.example" => {[{10, 0, 0, 1}], []}})

      assert {:error, :restricted_address} = OAuth.fetch_client_metadata(@client_id)
    end

    test "rejects a non-resolvable client_id host via the SSRF client" do
      stub_dns(%{"client.example" => {[], []}})

      assert {:error, :dns_resolution_failed} = OAuth.fetch_client_metadata(@client_id)
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
