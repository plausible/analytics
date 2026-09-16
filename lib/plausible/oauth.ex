defmodule Plausible.OAuth do
  @moduledoc """
  Minimal OAuth 2.1 authorization server used to authenticate remote MCP
  connectors (e.g. Claude) against Plausible.

  Handles the grant lifecycle: creating an authorization code, redeeming it once,
  then issuing, resolving and revoking the tokens that follow. Validation lives in
  `Plausible.OAuth.PKCE`, `Plausible.OAuth.CIMD` and
  `Plausible.OAuth.ProtectedResources`.

  Only the `authorization_code` grant is implemented at the token endpoint;
  redeeming a refresh token is not wired up yet.
  """

  use Plausible.Repo

  alias Plausible.OAuth.{AuthorizationCode, Grant, PKCE, ProtectedResources, Token}

  # TTLs (in seconds)
  @authorization_code_ttl 600
  @access_token_ttl 3600
  @refresh_token_ttl 30 * 24 * 3600

  @type token_response() :: %{
          access_token: String.t(),
          refresh_token: String.t(),
          token_type: String.t(),
          expires_in: pos_integer(),
          scope: String.t()
        }

  @spec access_token_ttl() :: pos_integer()
  def access_token_ttl(), do: @access_token_ttl

  @spec refresh_token_ttl() :: pos_integer()
  def refresh_token_ttl(), do: @refresh_token_ttl

  @doc """
  Returns the scopes a stored authorization still grants.

  The scopes, team and resource recorded on a code or grant are the most it can
  ever grant, and both can go stale: the user can be removed from the team, and
  a scope can be withdrawn from the resource.

  Returns the recorded scopes the resource still supports, or
  `{:error, :stale_authorization}` if the user has left the team or none of the
  scopes are left. Every team role counts as membership, guests included.
  """
  @spec effective_scopes(AuthorizationCode.t() | Grant.t()) ::
          {:ok, [String.t()]} | {:error, :stale_authorization}
  def effective_scopes(%struct{} = authorization) when struct in [AuthorizationCode, Grant] do
    with {:ok, resource} <- normalize_resource(authorization.resource),
         :ok <- check_membership(authorization.user_id, authorization.team_id),
         [_ | _] = scopes <-
           Enum.filter(resource.scopes_supported, &(&1 in authorization.scopes)) do
      {:ok, scopes}
    else
      _ -> {:error, :stale_authorization}
    end
  end

  defp check_membership(user_id, team_id) do
    query =
      from(tm in Plausible.Teams.Membership,
        where: tm.user_id == ^user_id and tm.team_id == ^team_id
      )

    if Repo.exists?(query), do: :ok, else: {:error, :not_a_member}
  end

  @doc """
  Creates a single-use authorization code bound to the given user and team.

  `attrs` must carry `:client_id`, `:redirect_uri`, `:code_challenge`,
  `:code_challenge_method`, `:resource` and a non-empty `:scopes` list, and may
  carry `:client_name`.

  `:resource` and `:scopes` are re-resolved here rather than trusted from the
  caller, since the consent screen was rendered by a separate request.

  Returns the raw code - only its hash is stored, so this is the only point
  where the raw value exists.
  """
  @spec create_authorization_code(Plausible.Auth.User.t(), Plausible.Teams.Team.t(), map()) ::
          {:ok, String.t()} | {:error, Ecto.Changeset.t() | :invalid_scope | :invalid_target}
  def create_authorization_code(user, team, attrs) do
    with {:ok, resource} <- normalize_resource(attrs[:resource]),
         {:ok, scopes} <- ProtectedResources.normalize_granted_scopes(attrs[:scopes], resource) do
      code = Token.generate(:code)

      changeset =
        AuthorizationCode.changeset(%{
          code_hash: code.hash,
          client_id: attrs.client_id,
          client_name: attrs[:client_name],
          redirect_uri: attrs.redirect_uri,
          code_challenge: attrs.code_challenge,
          code_challenge_method: attrs.code_challenge_method,
          scopes: scopes,
          resource: ProtectedResources.get_resource_url(resource),
          user_id: user.id,
          team_id: team.id,
          expires_at: NaiveDateTime.add(now(), @authorization_code_ttl, :second)
        })

      with {:ok, _auth_code} <- Repo.insert(changeset), do: {:ok, code.raw}
    end
  end

  @doc """
  Consumes an authorization code and validates it against what the client
  presented at the token endpoint: `:verifier`, `:client_id`, `:redirect_uri`
  and `:resource`. Every one of those must equal the value bound to the code at
  authorize-time.

  `:client_id` is checked even though PKCE already proves possession of the
  verifier, as required by
  [OAuth 2.1 §4.1.3](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-token-endpoint-extension).

  The row is deleted on lookup whether or not the later checks pass, so a code
  can only ever be redeemed once.

  `effective_scopes/1` must still return exactly the scopes the user approved, so
  the code is rejected once the user leaves the team or a scope is withdrawn.
  """
  @type presented_grant() :: %{
          required(:verifier) => String.t(),
          required(:client_id) => String.t(),
          required(:redirect_uri) => String.t(),
          required(:resource) => String.t()
        }

  @spec consume_authorization_code(String.t(), presented_grant()) ::
          {:ok, AuthorizationCode.t()} | {:error, :invalid_grant}
  def consume_authorization_code(code, presented) when is_binary(code) do
    with {:ok, auth_code} <- delete_and_fetch_code(Token.hash(code)),
         :ok <- check_not_expired(auth_code.expires_at),
         :ok <-
           PKCE.verify(
             auth_code.code_challenge,
             presented.verifier,
             auth_code.code_challenge_method
           ),
         :ok <- match(auth_code.client_id, presented.client_id),
         :ok <- match(auth_code.redirect_uri, presented.redirect_uri),
         :ok <- match(auth_code.resource, presented.resource),
         :ok <- check_still_grantable(auth_code) do
      {:ok, auth_code}
    end
  end

  def consume_authorization_code(_code, _presented), do: {:error, :invalid_grant}

  # Narrowing to the remaining scopes would be defensible (RFC 6749 section 3.3),
  # but withdrawing a scope is meant to stop existing grants, so we reject and
  # require re-consent.
  defp check_still_grantable(auth_code) do
    case effective_scopes(auth_code) do
      {:ok, scopes} -> match(scopes, auth_code.scopes)
      {:error, :stale_authorization} -> {:error, :invalid_grant}
    end
  end

  defp delete_and_fetch_code(code_hash) do
    query = from(c in AuthorizationCode, where: c.code_hash == ^code_hash, select: c)

    case Repo.delete_all(query) do
      {1, [code]} -> {:ok, code}
      {0, _} -> {:error, :invalid_grant}
    end
  end

  @doc """
  Creates a grant from a consumed authorization code, inheriting its client,
  scopes, resource, user and team.

  Issues an access and a refresh token together. Both raw values are returned
  once here and only their hashes are kept.
  """
  @spec issue_token(AuthorizationCode.t()) ::
          {:ok, token_response()} | {:error, Ecto.Changeset.t()}
  def issue_token(%AuthorizationCode{} = auth_code) do
    access = Token.generate(:access)
    refresh = Token.generate(:refresh)
    now = now()

    changeset =
      Grant.changeset(%{
        client_id: auth_code.client_id,
        client_name: auth_code.client_name,
        scopes: auth_code.scopes,
        resource: auth_code.resource,
        user_id: auth_code.user_id,
        team_id: auth_code.team_id,
        access_token_hash: access.hash,
        access_token_hint: access.hint,
        access_token_expires_at: NaiveDateTime.add(now, @access_token_ttl, :second),
        refresh_token_hash: refresh.hash,
        refresh_token_hint: refresh.hint,
        refresh_token_expires_at: NaiveDateTime.add(now, @refresh_token_ttl, :second)
      })

    with {:ok, _grant} <- Repo.insert(changeset) do
      {:ok,
       %{
         access_token: access.raw,
         refresh_token: refresh.raw,
         token_type: "Bearer",
         expires_in: @access_token_ttl,
         scope: Enum.join(auth_code.scopes, " ")
       }}
    end
  end

  @doc """
  Looks up the grant a raw access token belongs to, preloading the bound user
  and team. Mirrors `Plausible.Auth.find_api_key/1`.

  Expired and revoked grants are refused here rather than left to the cleanup
  worker, so revocation takes effect on the next request.

  `resource` is the protected resource the token is presented to. A token issued
  for a different resource is not found, and taking `resource` as an argument
  means there is no way to look a token up without checking it
  ([RFC 8707](https://www.rfc-editor.org/rfc/rfc8707.html)).

  Expired, revoked and wrong-resource tokens all return `{:error, :invalid_token}`
  ([RFC 6750 section 3.1](https://www.rfc-editor.org/rfc/rfc6750.html#section-3.1)).
  """
  @spec find_access_token(String.t(), ProtectedResources.t()) ::
          {:ok, Grant.t()} | {:error, :invalid_token}
  def find_access_token(raw_access, resource) when is_binary(raw_access) do
    resource_url = ProtectedResources.get_resource_url(resource)

    query =
      from(g in Grant,
        where:
          g.access_token_hash == ^Token.hash(raw_access) and
            g.resource == ^resource_url and
            g.access_token_expires_at > ^now() and
            is_nil(g.revoked_at),
        preload: [:user, :team]
      )

    case Repo.one(query) do
      nil -> {:error, :invalid_token}
      grant -> {:ok, grant}
    end
  end

  def find_access_token(_raw_access, _resource), do: {:error, :invalid_token}

  @doc """
  Revokes a grant, invalidating its access and refresh tokens.

  Recorded on the row rather than deleted, so a revoked connection can still be
  displayed and its `previous_refresh_token_hash` still recognised. Idempotent:
  an already-revoked grant keeps its original `revoked_at`.
  """
  @spec revoke_grant(Grant.t()) :: :ok
  def revoke_grant(%Grant{} = grant) do
    now = now()

    Repo.update_all(
      from(g in Grant, where: g.id == ^grant.id and is_nil(g.revoked_at)),
      set: [revoked_at: now, updated_at: now]
    )

    :ok
  end

  defp normalize_resource(resource) do
    case ProtectedResources.get_by_url(resource) do
      {:ok, protected_resource} -> {:ok, protected_resource}
      {:error, :not_found} -> {:error, :invalid_target}
    end
  end

  defp check_not_expired(expires_at) do
    if NaiveDateTime.compare(expires_at, now()) == :gt do
      :ok
    else
      {:error, :invalid_grant}
    end
  end

  defp match(same, same), do: :ok
  defp match(_, _), do: {:error, :invalid_grant}

  # Second precision matches the stored `:naive_datetime` columns.
  defp now(), do: NaiveDateTime.utc_now(:second)
end
