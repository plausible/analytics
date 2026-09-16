defmodule Plausible.OAuthTest do
  use Plausible.DataCase, async: true
  use Plausible.Test.Support.DNS

  alias Plausible.Auth.Scopes
  alias Plausible.OAuth
  alias Plausible.OAuth.{AuthorizationCode, Grant, ProtectedResources, Token}

  @client_id "https://client.example.com/oauth-metadata"
  @redirect_uri "https://client.example.com/callback"

  defp pkce do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp resource(), do: ProtectedResources.get_resource_url(mcp())

  defp mcp(), do: ProtectedResources.mcp()

  defp supported_scopes(), do: mcp().scopes_supported

  defp create_code(user, team, challenge, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          code_challenge: challenge,
          code_challenge_method: "S256",
          scopes: supported_scopes(),
          resource: resource()
        },
        overrides
      )

    OAuth.create_authorization_code(user, team, attrs)
  end

  defp past, do: NaiveDateTime.add(NaiveDateTime.utc_now(:second), -1, :second)

  defp get_code(raw_code) do
    Plausible.Repo.get_by!(AuthorizationCode, code_hash: Token.hash(raw_code))
  end

  defp expire_code(raw_code, at) do
    Plausible.Repo.update_all(
      from(c in AuthorizationCode, where: c.code_hash == ^Token.hash(raw_code)),
      set: [expires_at: at]
    )
  end

  defp expire_grant(raw_token, at) do
    Plausible.Repo.update_all(
      from(g in Grant, where: g.access_token_hash == ^Token.hash(raw_token)),
      set: [access_token_expires_at: at, refresh_token_expires_at: at]
    )
  end

  defp set_code_scopes(raw_code, scopes) do
    Plausible.Repo.update_all(
      from(c in AuthorizationCode, where: c.code_hash == ^Token.hash(raw_code)),
      set: [scopes: scopes]
    )
  end

  defp remove_from_team(user, team) do
    Plausible.Repo.delete_all(
      from(tm in Plausible.Teams.Membership,
        where: tm.user_id == ^user.id and tm.team_id == ^team.id
      )
    )
  end

  defp issue_grant(user, team, overrides \\ %{}) do
    {verifier, challenge} = pkce()
    {:ok, code} = create_code(user, team, challenge, overrides)

    {:ok, consumed_code} =
      OAuth.consume_authorization_code(code, %{
        verifier: verifier,
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        resource: resource()
      })

    {:ok, response} = OAuth.issue_token(consumed_code)
    {:ok, grant} = OAuth.find_access_token(response.access_token, mcp())

    {grant, response.access_token}
  end

  setup do
    user = new_user()
    {:ok, team} = Plausible.Teams.get_or_create(user)
    {:ok, user: user, team: team}
  end

  describe "effective_scopes/1" do
    test "returns the granted scopes while nothing has changed", %{user: user, team: team} do
      {_verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      assert OAuth.effective_scopes(get_code(code)) == {:ok, supported_scopes()}
    end

    test "narrows to the scopes the resource still supports", %{user: user, team: team} do
      {_verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)
      set_code_scopes(code, [Scopes.stats_read() | supported_scopes()])

      assert OAuth.effective_scopes(get_code(code)) == {:ok, supported_scopes()}
    end

    test "refuses once every granted scope has been withdrawn", %{user: user, team: team} do
      {_verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)
      set_code_scopes(code, [Scopes.stats_read()])

      assert OAuth.effective_scopes(get_code(code)) == {:error, :stale_authorization}
    end

    test "refuses a zero-scope authorization rather than defaulting it", %{
      user: user,
      team: team
    } do
      {_verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)
      set_code_scopes(code, [])

      assert OAuth.effective_scopes(get_code(code)) == {:error, :stale_authorization}
    end

    test "refuses once the user is no longer a member of the team", %{user: user, team: team} do
      {_verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      remove_from_team(user, team)

      assert OAuth.effective_scopes(get_code(code)) == {:error, :stale_authorization}
    end

    test "counts a guest as a member of the team", %{team: team} do
      site = new_site(team: team)
      guest = add_guest(site, role: :viewer)

      {_verifier, challenge} = pkce()
      {:ok, code} = create_code(guest, team, challenge)

      assert OAuth.effective_scopes(get_code(code)) == {:ok, supported_scopes()}
    end

    test "resolves a grant the same way as a code", %{user: user, team: team} do
      {grant, _access_token} = issue_grant(user, team)

      assert OAuth.effective_scopes(grant) == {:ok, supported_scopes()}

      remove_from_team(user, team)

      assert OAuth.effective_scopes(grant) == {:error, :stale_authorization}
    end
  end

  describe "create_authorization_code/3" do
    test "accepts a long client_id URL and redirect_uri", %{user: user, team: team} do
      {_verifier, challenge} = pkce()
      long_url = "https://client.example.com/" <> String.duplicate("a", 500)

      assert {:ok, code} =
               create_code(user, team, challenge, %{
                 client_id: long_url,
                 redirect_uri: long_url
               })

      assert_matches %AuthorizationCode{
                       client_id: ^long_url,
                       redirect_uri: ^long_url
                     } = get_code(code)
    end

    test "rejects an over-long client_name from the metadata document", %{
      user: user,
      team: team
    } do
      {_verifier, challenge} = pkce()

      assert {:error, changeset} =
               create_code(user, team, challenge, %{
                 client_name: String.duplicate("N", 256)
               })

      assert {"should be at most %{count} character(s)", _} = changeset.errors[:client_name]
    end

    test "rejects a code_challenge that is not a 43-byte S256 digest", %{user: user, team: team} do
      for challenge <- [String.duplicate("x", 42), String.duplicate("x", 300)] do
        assert {:error, changeset} = create_code(user, team, challenge)
        assert {"should be %{count} byte(s)", _} = changeset.errors[:code_challenge]
      end
    end

    test "refuses a resource this server does not protect", %{user: user, team: team} do
      {_verifier, challenge} = pkce()

      assert {:error, :invalid_target} =
               create_code(user, team, challenge, %{
                 resource: "https://elsewhere.example.com/mcp"
               })

      assert Plausible.Repo.aggregate(AuthorizationCode, :count) == 0
    end

    test "refuses an absent resource", %{user: user, team: team} do
      {_verifier, challenge} = pkce()

      assert {:error, :invalid_target} = create_code(user, team, challenge, %{resource: nil})

      assert Plausible.Repo.aggregate(AuthorizationCode, :count) == 0
    end

    test "rejects an over-long redirect_uri", %{user: user, team: team} do
      {_verifier, challenge} = pkce()

      assert {:error, changeset} =
               create_code(user, team, challenge, %{
                 redirect_uri: "https://client.example.com/" <> String.duplicate("a", 2048)
               })

      assert {"should be at most %{count} byte(s)", _} = changeset.errors[:redirect_uri]
    end

    # Unreachable through the context, which normalizes `resource` first.
    test "bounds the stored resource" do
      changeset =
        AuthorizationCode.changeset(%{
          code_hash: "hash",
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          code_challenge: String.duplicate("x", 43),
          code_challenge_method: "S256",
          scopes: [],
          resource: "https://plausible.example.com/" <> String.duplicate("a", 2048),
          user_id: 1,
          team_id: 1,
          expires_at: NaiveDateTime.utc_now(:second)
        })

      assert {"should be at most %{count} byte(s)", _} = changeset.errors[:resource]
    end

    test "refuses a scope this server does not support", %{user: user, team: team} do
      {_verifier, challenge} = pkce()

      assert {:error, :invalid_scope} =
               create_code(user, team, challenge, %{scopes: ["sites:read:*", "admin:write"]})

      assert Plausible.Repo.aggregate(AuthorizationCode, :count) == 0
    end

    test "refuses an absent or empty scope set rather than defaulting it", %{
      user: user,
      team: team
    } do
      {_verifier, challenge} = pkce()

      for scopes <- [nil, [], "", Enum.join(supported_scopes(), " ")] do
        assert {:error, :invalid_scope} = create_code(user, team, challenge, %{scopes: scopes})
      end

      assert Plausible.Repo.aggregate(AuthorizationCode, :count) == 0
    end
  end

  # Only reachable directly: the context normalizes `scopes` before either
  # changeset sees it.
  describe "schema changesets" do
    test "refuse nil scopes rather than letting the insert raise" do
      code_attrs = %{
        code_hash: "hash",
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        code_challenge: String.duplicate("x", 43),
        code_challenge_method: "S256",
        resource: resource(),
        user_id: 1,
        team_id: 1,
        expires_at: NaiveDateTime.utc_now(:second)
      }

      grant_attrs = %{
        user_id: 1,
        team_id: 1,
        client_id: @client_id,
        resource: resource(),
        access_token_hash: "ah",
        access_token_hint: "hint",
        access_token_expires_at: NaiveDateTime.utc_now(:second),
        refresh_token_hash: "rh",
        refresh_token_hint: "hint",
        refresh_token_expires_at: NaiveDateTime.utc_now(:second)
      }

      for changeset <- [
            AuthorizationCode.changeset(Map.put(code_attrs, :scopes, nil)),
            Grant.changeset(Map.put(grant_attrs, :scopes, nil))
          ] do
        refute changeset.valid?
        assert {"can't be blank", _} = changeset.errors[:scopes]
      end

      # An empty list is the column default, refused where it matters, not here.
      assert AuthorizationCode.changeset(Map.put(code_attrs, :scopes, [])).valid?
      assert Grant.changeset(Map.put(grant_attrs, :scopes, [])).valid?
    end
  end

  describe "consume_authorization_code/2" do
    # Without a guard, a repeated `?code[]=` param would be hashed as the
    # concatenation of its parts.
    test "rejects a non-binary code rather than raising" do
      presented = %{
        verifier: "v",
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        resource: resource()
      }

      assert {:error, :invalid_grant} = OAuth.consume_authorization_code(nil, presented)
      assert {:error, :invalid_grant} = OAuth.consume_authorization_code(["ab", "c"], presented)
    end

    test "returns the code and binds user, team and scopes", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      assert {:ok, consumed_code} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })

      assert_matches %AuthorizationCode{
                       user_id: ^user.id,
                       team_id: ^team.id,
                       scopes: ^supported_scopes(),
                       client_id: ^@client_id
                     } = consumed_code
    end

    test "is single-use", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      assert {:ok, _consumed_code} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end

    test "burns the code even when validation fails", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: "wrong-verifier",
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end

    test "rejects a mismatched client_id", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: "https://other.example.com/oauth-metadata",
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end

    test "rejects a missing client_id", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: nil,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end

    test "rejects a mismatched redirect_uri", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: "https://client.example.com/other",
                 resource: resource()
               })
    end

    test "rejects a mismatched resource", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: "https://elsewhere.example.com/mcp"
               })
    end

    test "rejects an unknown code" do
      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code("nope", %{
                 verifier: "v",
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end

    test "rejects an expired code", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      expire_code(code, past())

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end

    test "rejects a code whose user has since left the team", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      remove_from_team(user, team)

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end

    test "rejects rather than narrows a code naming a withdrawn scope", %{
      user: user,
      team: team
    } do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)
      set_code_scopes(code, [Scopes.stats_read() | supported_scopes()])

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end
  end

  describe "issue_token/1 and find_access_token/2" do
    test "issues a bearer token resolving to the code's user, team and scopes", %{
      user: user,
      team: team
    } do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge, %{scopes: ["sites:read:*"]})

      {:ok, consumed_code} =
        OAuth.consume_authorization_code(code, %{
          verifier: verifier,
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          resource: resource()
        })

      assert {:ok, response} = OAuth.issue_token(consumed_code)

      assert_matches ^strict_map(%{
                       access_token: ^any(:string),
                       refresh_token: ^any(:string),
                       token_type: "Bearer",
                       expires_in: ^OAuth.access_token_ttl(),
                       scope: "sites:read:*"
                     }) = response

      assert {:ok, token} = OAuth.find_access_token(response.access_token, mcp())

      resource = resource()

      assert_matches %Grant{
                       user: %{id: ^user.id},
                       team: %{id: ^team.id},
                       scopes: ["sites:read:*"],
                       resource: ^resource
                     } = token
    end

    test "does not persist the raw token", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      {:ok, consumed_code} =
        OAuth.consume_authorization_code(code, %{
          verifier: verifier,
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          resource: resource()
        })

      {:ok, response} = OAuth.issue_token(consumed_code)

      stored =
        Plausible.Repo.one!(
          from g in Grant, where: g.access_token_hash == ^Token.hash(response.access_token)
        )

      assert_matches %Grant{
                       access_token_hash: ^any(:string, &(&1 != response.access_token)),
                       access_token_hint:
                         ^any(:string, &String.ends_with?(response.access_token, &1))
                     } = stored
    end

    test "rejects an unknown token" do
      assert {:error, :invalid_token} = OAuth.find_access_token("made-up", mcp())
    end

    # `:crypto.hash/2` takes iodata, so an unguarded ["ab", "c"] would hash to
    # the same key as "abc". Plug decodes a repeated query param into a list.
    test "rejects a non-binary token rather than raising" do
      assert {:error, :invalid_token} = OAuth.find_access_token(nil, mcp())
      assert {:error, :invalid_token} = OAuth.find_access_token(["ab", "c"], mcp())
      assert {:error, :invalid_token} = OAuth.find_access_token(%{"a" => "b"}, mcp())
    end

    test "rejects a live token presented to a resource it was not issued for", %{
      user: user,
      team: team
    } do
      {_grant, access_token} = issue_grant(user, team)

      assert {:error, :invalid_token} =
               OAuth.find_access_token(access_token, %{
                 resource_path: "/elsewhere",
                 scopes_supported: []
               })

      # Otherwise live, so the refusal above is the audience and nothing else.
      assert {:ok, _grant} = OAuth.find_access_token(access_token, mcp())
    end

    test "rejects an expired token", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      {:ok, consumed_code} =
        OAuth.consume_authorization_code(code, %{
          verifier: verifier,
          client_id: @client_id,
          redirect_uri: @redirect_uri,
          resource: resource()
        })

      {:ok, response} = OAuth.issue_token(consumed_code)

      expire_grant(response.access_token, past())

      assert {:error, :invalid_token} = OAuth.find_access_token(response.access_token, mcp())
    end
  end

  describe "revoke_grant/1" do
    test "invalidates the grant's access token", %{user: user, team: team} do
      {grant, access_token} = issue_grant(user, team)

      assert :ok = OAuth.revoke_grant(grant)

      assert {:error, :invalid_token} = OAuth.find_access_token(access_token, mcp())
    end

    test "keeps the original revoked_at when repeated", %{user: user, team: team} do
      {grant, _access_token} = issue_grant(user, team)

      assert :ok = OAuth.revoke_grant(grant)

      revoked_at = past()

      Plausible.Repo.update_all(
        from(g in Grant, where: g.id == ^grant.id),
        set: [revoked_at: revoked_at]
      )

      assert :ok = OAuth.revoke_grant(grant)

      assert_matches %Grant{revoked_at: ^revoked_at} = Plausible.Repo.get!(Grant, grant.id)
    end
  end
end
