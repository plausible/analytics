defmodule Plausible.OAuthTest do
  @moduledoc """
  Covers OAuth grant lifecycle.

  - `Step 1: create_authorization_code/3` issues a single-use code bound to a user,
     team, scopes and resource
  - `Step 2: consume_authorization_code/2` redeems that code, exactly once
  - `Step 3: issue_token/1 and find_access_token/2`: opens a grant from the redeemed code, returns token AND resolves an access token back to its grant
  """

  use Plausible.DataCase
  use Plausible.Test.Support.DNS

  alias Plausible.OAuth
  alias Plausible.OAuth.{AuthorizationCode, Grant, ProtectedResources, Token}

  @client_id "https://client.example.com/oauth-metadata"
  @redirect_uri "https://client.example.com/callback"

  setup do
    user = new_user()
    {:ok, team} = Plausible.Teams.get_or_create(user)
    {:ok, user: user, team: team}
  end

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
                       access_token_hash: ^Token.hash(response.access_token),
                       access_token_hint: ^String.slice(response.access_token, -4, 4)
                     } = stored
    end

    test "an access token stops resolving once the user leaves the team" do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      member = add_member(team, role: :editor)

      {_grant, access_token} = issue_grant(member, team)
      assert {:ok, _} = OAuth.find_access_token(access_token, mcp())

      Plausible.Teams.Membership
      |> Repo.get_by!(team_id: team.id, user_id: member.id)
      |> Repo.delete!()

      assert {:error, :invalid_token} = OAuth.find_access_token(access_token, mcp())
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

  defp past, do: NaiveDateTime.add(NaiveDateTime.utc_now(:second), -1, :second)

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
end
