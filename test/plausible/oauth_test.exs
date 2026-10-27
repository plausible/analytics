defmodule Plausible.OAuthTest do
  @moduledoc """
  Covers OAuth grant lifecycle.

  - `Step 1: create_authorization_code/3` issues a single-use code bound to a user,
     team, scopes and resource
  - `Step 2: consume_authorization_code/2` redeems that code, exactly once
  - `Step 3: issue_token/1 and find_access_token/2`: opens a grant from the redeemed code, returns token AND resolves an access token back to its grant
  - `Step 4: revoke_grant/1 and after_user_removed_from_team/2` invalidates both tokens
  - `Step 5: refresh_token/2` rotates both tokens
  """

  use Plausible.DataCase
  use Plausible.Test.Support.DNS

  alias Plausible.OAuth
  alias Plausible.OAuth.{AuthorizationCode, Grant, ProtectedResources, Token}

  @client_id "https://client.example.com/oauth-metadata"
  @redirect_uri "https://client.example.com/callback"

  setup [:create_user, :create_team]

  describe "Step 1: create_authorization_code/3" do
    test "refuses a resource this server does not know", %{user: user, team: team} do
      {_verifier, challenge} = pkce()

      for resource <- ["https://elsewhere.example.com/mcp", nil] do
        assert {:error, :invalid_target} =
                 create_code(user, team, challenge, %{resource: resource})
      end

      assert Plausible.Repo.aggregate(AuthorizationCode, :count) == 0
    end

    test "refuses a scope set this server cannot grant", %{user: user, team: team} do
      {_verifier, challenge} = pkce()

      for scopes <- [
            ["sites:read:*", "admin:write"],
            nil,
            [],
            "",
            Enum.join(supported_scopes(), " ")
          ] do
        assert {:error, :invalid_scope} = create_code(user, team, challenge, %{scopes: scopes})
      end

      assert Plausible.Repo.aggregate(AuthorizationCode, :count) == 0
    end

    test "stores a code bound to the user, team, scopes and resource", %{user: user, team: team} do
      {_verifier, challenge} = pkce()

      assert {:ok, raw_code} = create_code(user, team, challenge)

      stored = Plausible.Repo.one!(AuthorizationCode)

      assert_matches %AuthorizationCode{
                       code_hash: ^Token.hash(raw_code),
                       client_id: ^@client_id,
                       redirect_uri: ^@redirect_uri,
                       code_challenge: ^challenge,
                       code_challenge_method: "S256",
                       scopes: ^supported_scopes(),
                       resource: ^resource(),
                       user_id: ^user.id,
                       team_id: ^team.id
                     } = stored

      assert NaiveDateTime.compare(stored.expires_at, NaiveDateTime.utc_now()) == :gt
    end
  end

  describe "Step 2: consume_authorization_code/2" do
    test "rejects an unknown code" do
      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code("nope", %{
                 verifier: "v",
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end

    test "rejects when the presented values don't match the code", %{user: user, team: team} do
      for override <- [
            %{client_id: "https://other.example.com/oauth-metadata"},
            %{client_id: nil},
            %{redirect_uri: "https://client.example.com/other"},
            %{resource: "https://elsewhere.example.com/mcp"}
          ] do
        {verifier, challenge} = pkce()
        {:ok, code} = create_code(user, team, challenge)

        presented =
          Map.merge(
            %{
              verifier: verifier,
              client_id: @client_id,
              redirect_uri: @redirect_uri,
              resource: resource()
            },
            override
          )

        assert {:error, :invalid_grant} = OAuth.consume_authorization_code(code, presented)
      end
    end

    test "rejects an expired code", %{user: user, team: team} do
      {verifier, challenge} = pkce()
      {:ok, code} = create_code(user, team, challenge)

      Plausible.Repo.update_all(
        from(c in AuthorizationCode, where: c.code_hash == ^Token.hash(code)),
        set: [expires_at: past()]
      )

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

      Plausible.Repo.delete_all(
        from(tm in Plausible.Teams.Membership,
          where: tm.user_id == ^user.id and tm.team_id == ^team.id
        )
      )

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
    end

    test "rejects a code whose user has since been downgraded to guest" do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      member = add_member(team, role: :editor)

      {verifier, challenge} = pkce()
      {:ok, code} = create_code(member, team, challenge)

      Plausible.Teams.Membership
      |> Repo.get_by!(team_id: team.id, user_id: member.id)
      |> Ecto.Changeset.change(role: :guest)
      |> Repo.update!()

      assert {:error, :invalid_grant} =
               OAuth.consume_authorization_code(code, %{
                 verifier: verifier,
                 client_id: @client_id,
                 redirect_uri: @redirect_uri,
                 resource: resource()
               })
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

    test "burns the code on successful consume, it can't be consumed twice", %{
      user: user,
      team: team
    } do
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

    test "burns the code even when validation fails, can't guess verifier", %{
      user: user,
      team: team
    } do
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
  end

  describe "Step 3: issue_token/1 and find_access_token/2" do
    test "rejects an unknown token" do
      assert {:error, :invalid_token} = OAuth.find_access_token("made-up", mcp())
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

      # Verify that the token works for the correct resource.
      assert {:ok, _grant, _role} = OAuth.find_access_token(access_token, mcp())
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

      Plausible.Repo.update_all(
        from(g in Grant, where: g.access_token_hash == ^Token.hash(response.access_token)),
        set: [access_token_expires_at: past(), refresh_token_expires_at: past()]
      )

      assert {:error, :invalid_token} = OAuth.find_access_token(response.access_token, mcp())
    end

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
                       expires_in: ^OAuth.access_token_ttl_seconds(),
                       scope: "sites:read:*"
                     }) = response

      assert {:ok, token, _role} = OAuth.find_access_token(response.access_token, mcp())

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
                       access_token_hash: ^Token.hash(response.access_token),
                       access_token_hint: ^String.slice(response.access_token, -4, 4)
                     } = stored
    end

    test "an access token stops resolving once the user leaves the team" do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      member = add_member(team, role: :editor)

      {_grant, access_token} = issue_grant(member, team)
      assert {:ok, _, _role} = OAuth.find_access_token(access_token, mcp())

      Plausible.Teams.Membership
      |> Repo.get_by!(team_id: team.id, user_id: member.id)
      |> Repo.delete!()

      assert {:error, :invalid_token} = OAuth.find_access_token(access_token, mcp())
    end

    test "an access token stops resolving once the user is demoted to guest" do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      member = add_member(team, role: :editor)

      {_grant, access_token} = issue_grant(member, team)
      assert {:ok, _, :editor} = OAuth.find_access_token(access_token, mcp())

      Plausible.Teams.Membership
      |> Repo.get_by!(team_id: team.id, user_id: member.id)
      |> Ecto.Changeset.change(role: :guest)
      |> Repo.update!()

      assert {:error, :invalid_token} = OAuth.find_access_token(access_token, mcp())
    end
  end

  describe "Step 4: revoke_grant/1 and after_user_removed_from_team/2" do
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

    test "removing a member revokes the grants they held against the team" do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      member = add_member(team, role: :editor)

      {grant, access_token} = issue_grant(member, team)

      other_owner = new_user()
      {:ok, other_team} = Plausible.Teams.get_or_create(other_owner)
      add_member(other_team, role: :editor, user: member)

      {kept, kept_token} = issue_grant(member, other_team)

      assert {:ok, _} =
               Plausible.Teams.Memberships.Remove.remove(team, member.id, owner,
                 send_email?: false
               )

      assert %Grant{revoked_at: revoked_at} = Plausible.Repo.get!(Grant, grant.id)
      assert revoked_at
      assert {:error, :invalid_token} = OAuth.find_access_token(access_token, mcp())

      assert_matches %Grant{revoked_at: nil} = Plausible.Repo.get!(Grant, kept.id)
      assert {:ok, _, _role} = OAuth.find_access_token(kept_token, mcp())
    end

    test "a member leaving revokes the grants they held against the team" do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      member = add_member(team, role: :editor)

      {grant, _access_token} = issue_grant(member, team)

      other_owner = new_user()
      {:ok, other_team} = Plausible.Teams.get_or_create(other_owner)
      add_member(other_team, role: :editor, user: member)

      {kept, kept_token} = issue_grant(member, other_team)

      assert {:ok, _} =
               Plausible.Teams.Memberships.Leave.leave(team, member, send_email?: false)

      assert %Grant{revoked_at: revoked_at} = Plausible.Repo.get!(Grant, grant.id)
      assert revoked_at

      assert_matches %Grant{revoked_at: nil} = Plausible.Repo.get!(Grant, kept.id)
      assert {:ok, _, _role} = OAuth.find_access_token(kept_token, mcp())
    end
  end

  describe "Step 5: refresh_token/2" do
    test "rejects an unknown token" do
      assert {:error, :invalid_grant} = OAuth.refresh_token("made-up", %{})
      assert {:error, :invalid_grant} = OAuth.refresh_token(nil, %{})
    end

    test "rejects a revoked grant", %{user: user, team: team} do
      response_a = issue_tokens(user, team)
      {:ok, grant, _role} = OAuth.find_access_token(response_a.access_token, mcp())

      :ok = OAuth.revoke_grant(grant)

      assert {:error, :invalid_grant} = OAuth.refresh_token(response_a.refresh_token, %{})
    end

    test "rejects an expired token", %{user: user, team: team} do
      response_a = issue_tokens(user, team)

      Plausible.Repo.update_all(
        from(g in Grant, where: g.refresh_token_hash == ^Token.hash(response_a.refresh_token)),
        set: [refresh_token_expires_at: past()]
      )

      assert {:error, :invalid_grant} = OAuth.refresh_token(response_a.refresh_token, %{})
    end

    test "rejects a grant whose user has since left the team" do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      member = add_member(team, role: :editor)
      response_a = issue_tokens(member, team)

      Plausible.Teams.Membership
      |> Repo.get_by!(team_id: team.id, user_id: member.id)
      |> Repo.delete!()

      assert {:error, :invalid_grant} = OAuth.refresh_token(response_a.refresh_token, %{})
    end

    test "rejects a grant whose user has since been downgraded to guest" do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      member = add_member(team, role: :editor)
      response_a = issue_tokens(member, team)

      Plausible.Teams.Membership
      |> Repo.get_by!(team_id: team.id, user_id: member.id)
      |> Ecto.Changeset.change(role: :guest)
      |> Repo.update!()

      assert {:error, :invalid_grant} = OAuth.refresh_token(response_a.refresh_token, %{})
    end

    test "accepts valid refresh token, rotates access and refresh token, invalidates old access token",
         %{user: user, team: team} do
      response_a = issue_tokens(user, team)
      assert {:ok, initial_grant, _role} = OAuth.find_access_token(response_a.access_token, mcp())
      # make it about to expire
      initial_grant =
        initial_grant
        |> Ecto.Changeset.change(
          refresh_token_expires_at:
            :second |> NaiveDateTime.utc_now() |> NaiveDateTime.add(5, :second)
        )
        |> Repo.update!()

      assert {:ok, response_b} =
               OAuth.refresh_token(response_a.refresh_token, %{})

      assert_matches ^strict_map(%{
                       access_token: ^any(:string),
                       refresh_token: ^any(:string),
                       token_type: "Bearer",
                       expires_in: ^OAuth.access_token_ttl_seconds(),
                       scope: ^Enum.join(supported_scopes(), " ")
                     }) = response_b

      refute response_b.access_token == response_a.access_token
      refute response_b.refresh_token == response_a.refresh_token

      assert {:error, :invalid_token} = OAuth.find_access_token(response_a.access_token, mcp())
      assert {:ok, grant, _role} = OAuth.find_access_token(response_b.access_token, mcp())

      assert_matches %Grant{
                       user_id: ^user.id,
                       team_id: ^team.id,
                       access_token_hash: ^Token.hash(response_b.access_token),
                       access_token_hint: ^String.slice(response_b.access_token, -4, 4),
                       refresh_token_hash: ^Token.hash(response_b.refresh_token),
                       refresh_token_hint: ^String.slice(response_b.refresh_token, -4, 4),
                       previous_refresh_token_hash: ^Token.hash(response_a.refresh_token),
                       rotated_at: %NaiveDateTime{},
                       revoked_at: nil
                     } = grant

      assert NaiveDateTime.after?(
               grant.refresh_token_expires_at,
               initial_grant.refresh_token_expires_at
             )
    end

    test "accepts a request specifying client ID, resource and scopes; rejects without invalidating the grant if any of them are invalid",
         %{
           user: user,
           team: team
         } do
      response_a = issue_tokens(user, team)

      expected_params = %{
        client_id: @client_id,
        resource: resource(),
        scope: response_a.scope
      }

      assert {:ok, response_b} =
               OAuth.refresh_token(response_a.refresh_token, expected_params)

      for {invalid_params, expected_error} <- [
            {%{expected_params | scope: "stats:write:*"}, {:error, :invalid_scope}},
            {%{expected_params | client_id: "https://other.example.com/oauth-metadata"},
             {:error, :invalid_grant}},
            {%{expected_params | resource: "https://other.example.com/mcp"},
             {:error, :invalid_grant}}
          ] do
        assert ^expected_error = OAuth.refresh_token(response_b.refresh_token, invalid_params)
      end

      assert {:ok, _} = OAuth.refresh_token(response_b.refresh_token, expected_params)
    end

    test "replay during grace: the previous refresh token on file is accepted (to prevent loss of access when fumbling refresh attempt due to bad network)",
         %{
           user: user,
           team: team
         } do
      response_a = issue_tokens(user, team)

      # client presents refresh token A, it's accepted, but the client loses the response
      {:ok, response_b} = OAuth.refresh_token(response_a.refresh_token, %{})
      {:ok, grant_b, _role} = OAuth.find_access_token(response_b.access_token, mcp())
      assert {:error, :invalid_token} = OAuth.find_access_token(response_a.access_token, mcp())

      # client presents refresh token A again, it's accepted
      assert {:ok, response_c} = OAuth.refresh_token(response_a.refresh_token, %{})
      assert {:ok, grant_c, _role} = OAuth.find_access_token(response_c.access_token, mcp())
      assert {:error, :invalid_token} = OAuth.find_access_token(response_b.access_token, mcp())

      # a refresh during the grace period doesn't move rotated at
      assert_matches %Grant{
                       id: ^grant_b.id,
                       previous_refresh_token_hash: ^Token.hash(response_b.refresh_token),
                       rotated_at: ^grant_b.rotated_at,
                       revoked_at: nil
                     } = grant_c

      # refresh token A is not on file any more, so this is not considered a refresh token replay scenario, the grant is not revoked
      assert {:error, :invalid_grant} = OAuth.refresh_token(response_a.refresh_token, %{})
      assert {:ok, _grant, _role} = OAuth.find_access_token(response_c.access_token, mcp())
    end

    test "replay outside grace: the previous refresh token on file is rejected and the whole grant is invalidated (to protect the user from an attacker taking over the grant with a logged / leaked refresh token)",
         %{
           user: user,
           team: team
         } do
      response_a = issue_tokens(user, team)

      # attacker or client presents refresh token A, it's accepted
      {:ok, response_b} = OAuth.refresh_token(response_a.refresh_token, %{})
      {:ok, grant_b, _role} = OAuth.find_access_token(response_b.access_token, mcp())
      assert {:error, :invalid_token} = OAuth.find_access_token(response_a.access_token, mcp())

      end_grace_period(response_b.refresh_token)

      # attacker or client presents refresh token A, it's rejected
      assert {:error, :invalid_grant} = OAuth.refresh_token(response_a.refresh_token, %{})

      # both attacker and client locked out
      assert {:error, :invalid_token} = OAuth.find_access_token(response_b.access_token, mcp())
      assert {:error, :invalid_grant} = OAuth.refresh_token(response_b.refresh_token, %{})
      assert Repo.reload!(grant_b).revoked_at
    end
  end

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

  defp end_grace_period(refresh_token) do
    Plausible.Repo.update_all(
      from(g in Grant, where: g.refresh_token_hash == ^Token.hash(refresh_token)),
      set: [
        rotated_at:
          NaiveDateTime.add(
            NaiveDateTime.utc_now(:second),
            -OAuth.refresh_grace_period_seconds(),
            :second
          )
      ]
    )
  end

  defp past, do: NaiveDateTime.add(NaiveDateTime.utc_now(:second), -1, :second)

  defp issue_grant(user, team, overrides \\ %{}) do
    response = issue_tokens(user, team, overrides)
    {:ok, grant, _role} = OAuth.find_access_token(response.access_token, mcp())

    {grant, response.access_token}
  end

  defp issue_tokens(user, team, overrides \\ %{}) do
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
    response
  end
end
