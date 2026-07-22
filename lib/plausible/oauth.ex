defmodule Plausible.OAuth do
  @moduledoc """
  Minimal, hand-rolled OAuth 2.1 authorization server used to authenticate
  remote MCP connectors (e.g. Claude) against Plausible.

  Client registration is **CIMD-only** (Client ID Metadata Documents): the
  `client_id` is an HTTPS URL pointing to a JSON metadata document that the
  authorization server fetches at authorize-time. There is no Dynamic Client
  Registration endpoint and no clients table.

  Security invariants enforced here:

    * PKCE with `S256` is mandatory (`plain` is rejected).
    * Authorization codes are single-use and short-lived.
    * The `resource` (RFC 8707) is threaded from authorize -> code -> token ->
      access token so that tokens are audience-bound.
    * Only hashes of codes/tokens are persisted (see `Plausible.OAuth.Token`).
    * The CIMD fetch never happens over an unguarded HTTP client - see
      `fetch_client_metadata/1`.
  """

  use Plausible.Repo

  alias Plausible.OAuth.{AccessToken, AuthorizationCode, Token}

  # TTLs (in seconds)
  @authorization_code_ttl 600
  @access_token_ttl 3600
  @refresh_token_ttl 60 * 60 * 24 * 30

  @supported_scopes ["stats:read:*", "sites:read:*"]

  # CIMD fetch limits (the SSRF-safe client owns IP/redirect protection).
  @fetch_timeout 5_000
  @max_metadata_bytes 1_000_000

  @type token_response() :: %{
          access_token: String.t(),
          token_type: String.t(),
          expires_in: pos_integer(),
          refresh_token: String.t(),
          scope: String.t()
        }

  @spec supported_scopes() :: [String.t()]
  def supported_scopes(), do: @supported_scopes

  @spec access_token_ttl() :: pos_integer()
  def access_token_ttl(), do: @access_token_ttl

  @doc """
  Normalizes a space-delimited `scope` request parameter against the supported
  scopes. An empty/absent request defaults to all supported scopes.
  """
  @spec normalize_scopes(String.t() | nil) :: [String.t()]
  def normalize_scopes(scope) when scope in [nil, ""], do: @supported_scopes

  def normalize_scopes(scope) do
    requested = scope |> String.split(" ", trim: true) |> MapSet.new()

    Enum.filter(@supported_scopes, &MapSet.member?(requested, &1))
    |> case do
      [] -> @supported_scopes
      scopes -> scopes
    end
  end

  ## Authorization codes

  @doc """
  Creates a single-use authorization code bound to the given user and team.

  `attrs` must include `:client_id`, `:redirect_uri`, `:code_challenge`,
  `:code_challenge_method`, `:scopes` and (optionally) `:resource`. Returns the
  raw code to be handed back to the client via the redirect.
  """
  @spec create_authorization_code(Plausible.Auth.User.t(), Plausible.Teams.Team.t() | nil, map()) ::
          {:ok, String.t()} | {:error, Ecto.Changeset.t()}
  def create_authorization_code(user, team, attrs) do
    code = Token.generate(:code)

    changeset =
      AuthorizationCode.changeset(%{
        code_hash: code.hash,
        client_id: attrs.client_id,
        client_name: attrs[:client_name],
        redirect_uri: attrs.redirect_uri,
        code_challenge: attrs.code_challenge,
        code_challenge_method: attrs.code_challenge_method,
        scopes: attrs.scopes,
        resource: attrs[:resource],
        user_id: user.id,
        team_id: team && team.id,
        expires_at: DateTime.add(DateTime.utc_now(), @authorization_code_ttl, :second)
      })

    case Repo.insert(changeset) do
      {:ok, _} -> {:ok, code.raw}
      {:error, _} = error -> error
    end
  end

  @doc """
  Atomically consumes an authorization code (single-use: the row is deleted on
  lookup regardless of subsequent validation) and validates it against the
  presented PKCE verifier, redirect URI and resource.
  """
  @spec consume_authorization_code(
          String.t(),
          String.t() | nil,
          String.t() | nil,
          String.t() | nil
        ) ::
          {:ok, AuthorizationCode.t()} | {:error, atom()}
  def consume_authorization_code(code, verifier, redirect_uri, resource) do
    with {:ok, auth_code} <- delete_and_fetch_code(Token.hash(code)),
         :ok <- check_not_expired(auth_code.expires_at),
         :ok <- verify_pkce(auth_code.code_challenge, verifier, auth_code.code_challenge_method),
         :ok <- match(auth_code.redirect_uri, redirect_uri),
         :ok <- match(auth_code.resource, resource) do
      {:ok, auth_code}
    end
  end

  defp delete_and_fetch_code(code_hash) do
    query = from(c in AuthorizationCode, where: c.code_hash == ^code_hash, select: c)

    case Repo.delete_all(query) do
      {1, [code]} -> {:ok, code}
      {0, _} -> {:error, :invalid_grant}
    end
  end

  ## Tokens

  @doc """
  Issues a fresh access/refresh token pair from a consumed authorization code.
  """
  @spec issue_tokens(AuthorizationCode.t()) ::
          {:ok, token_response()} | {:error, Ecto.Changeset.t()}
  def issue_tokens(%AuthorizationCode{} = auth_code) do
    now = DateTime.utc_now()
    access = Token.generate(:access)
    refresh = Token.generate(:refresh)

    changeset =
      AccessToken.changeset(%{
        access_token_hash: access.hash,
        access_token_prefix: access.prefix,
        refresh_token_hash: refresh.hash,
        refresh_token_prefix: refresh.prefix,
        client_id: auth_code.client_id,
        client_name: auth_code.client_name,
        scopes: auth_code.scopes,
        resource: auth_code.resource,
        user_id: auth_code.user_id,
        team_id: auth_code.team_id,
        access_token_expires_at: DateTime.add(now, @access_token_ttl, :second),
        refresh_token_expires_at: DateTime.add(now, @refresh_token_ttl, :second)
      })

    case Repo.insert(changeset) do
      {:ok, _} -> {:ok, token_response(access.raw, refresh.raw, auth_code.scopes)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Rotates a refresh token: the presented refresh token is invalidated and a new
  access/refresh pair is issued on the same row. Rotation is atomic, so a refresh
  token can only be redeemed once.
  """
  @spec refresh_tokens(String.t()) :: {:ok, token_response()} | {:error, atom()}
  def refresh_tokens(raw_refresh) do
    now = DateTime.utc_now()
    access = Token.generate(:access)
    refresh = Token.generate(:refresh)

    query =
      from(t in AccessToken,
        where:
          t.refresh_token_hash == ^Token.hash(raw_refresh) and
            t.refresh_token_expires_at > ^now,
        select: t
      )

    updates = [
      set: [
        access_token_hash: access.hash,
        access_token_prefix: access.prefix,
        refresh_token_hash: refresh.hash,
        refresh_token_prefix: refresh.prefix,
        access_token_expires_at: DateTime.add(now, @access_token_ttl, :second),
        refresh_token_expires_at: DateTime.add(now, @refresh_token_ttl, :second),
        updated_at: now
      ]
    ]

    case Repo.update_all(query, updates) do
      {1, [row]} -> {:ok, token_response(access.raw, refresh.raw, row.scopes)}
      {0, _} -> {:error, :invalid_grant}
    end
  end

  @doc """
  Looks up a valid (non-expired) access token by its raw value, preloading the
  bound user and team. Mirrors `Plausible.Auth.find_api_key/1`.
  """
  @spec find_access_token(String.t()) :: {:ok, AccessToken.t()} | {:error, :invalid_token}
  def find_access_token(raw_access) do
    query =
      from(t in AccessToken,
        where:
          t.access_token_hash == ^Token.hash(raw_access) and
            t.access_token_expires_at > ^DateTime.utc_now(),
        preload: [:user, :team]
      )

    case Repo.one(query) do
      nil -> {:error, :invalid_token}
      token -> {:ok, token}
    end
  end

  ## Grants management (user-facing "Connected applications")

  # Only refresh last_used_at at most once per this many seconds, to avoid a
  # write on every single MCP request.
  @last_used_throttle_seconds 60

  @doc """
  Lists a user's currently-usable OAuth grants (those whose access or refresh
  token has not yet expired), most recent first, with the bound team preloaded.
  """
  @spec list_grants(Plausible.Auth.User.t()) :: [AccessToken.t()]
  def list_grants(user) do
    now = DateTime.utc_now()

    Repo.all(
      from(t in AccessToken,
        where:
          t.user_id == ^user.id and
            (t.access_token_expires_at > ^now or t.refresh_token_expires_at > ^now),
        order_by: [desc: t.inserted_at],
        preload: [:team]
      )
    )
  end

  @doc """
  Revokes all grants a user holds that are bound to the given team.

  Called when a user loses access to a team (removed or leaves) so their MCP
  tokens are invalidated immediately rather than lingering until expiry. Returns
  the number of grants revoked.
  """
  @spec revoke_grants_for_team_member(Plausible.Auth.User.t(), Plausible.Teams.Team.t()) ::
          non_neg_integer()
  def revoke_grants_for_team_member(user, team) do
    {count, _} =
      Repo.delete_all(
        from(t in AccessToken, where: t.user_id == ^user.id and t.team_id == ^team.id)
      )

    count
  end

  @doc """
  Revokes (deletes) a grant by id, scoped to the owning user. Removing the row
  invalidates both the access and refresh tokens immediately.
  """
  @spec revoke_grant(Plausible.Auth.User.t(), integer() | String.t()) ::
          :ok | {:error, :not_found}
  def revoke_grant(user, id) do
    query = from(t in AccessToken, where: t.id == ^id and t.user_id == ^user.id)

    case Repo.delete_all(query) do
      {n, _} when n > 0 -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  @doc """
  Records that an access token was just used, throttled to at most once per
  minute to avoid a write on every request.
  """
  @spec mark_used(AccessToken.t()) :: :ok
  def mark_used(%AccessToken{id: id}) do
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, -@last_used_throttle_seconds, :second)

    Repo.update_all(
      from(t in AccessToken,
        where: t.id == ^id and (is_nil(t.last_used_at) or t.last_used_at < ^cutoff)
      ),
      set: [last_used_at: now]
    )

    :ok
  end

  defp token_response(access_raw, refresh_raw, scopes) do
    %{
      access_token: access_raw,
      token_type: "Bearer",
      expires_in: @access_token_ttl,
      refresh_token: refresh_raw,
      scope: Enum.join(scopes, " ")
    }
  end

  ## PKCE

  @doc """
  Verifies a PKCE code verifier against a stored challenge. Only `S256` is
  accepted; `plain` and unknown methods are rejected.
  """
  @spec verify_pkce(String.t(), String.t() | nil, String.t()) :: :ok | {:error, :invalid_grant}
  def verify_pkce(challenge, verifier, "S256")
      when is_binary(challenge) and is_binary(verifier) do
    computed = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    if Plug.Crypto.secure_compare(computed, challenge) do
      :ok
    else
      {:error, :invalid_grant}
    end
  end

  def verify_pkce(_challenge, _verifier, _method), do: {:error, :invalid_grant}

  ## Client ID Metadata Documents (CIMD)

  @doc """
  Fetches and validates a Client ID Metadata Document.

  The `client_id` MUST be the HTTPS URL of the document; the fetched document is
  validated to be self-referential (its `client_id` equals the requested URL) and
  to declare at least one `redirect_uris` entry.

  ## SSRF

  This performs a server-side GET against an attacker-influenced URL, which is an
  SSRF surface. IP/host filtering (private/reserved/loopback/link-local + DNS
  resolution, IP pinning, and per-hop redirect re-validation) is delegated to the
  shared `Plausible.SSRF` helper rather than hand-rolled here. Tests may inject a
  fetcher via `config :plausible, Plausible.OAuth, client_metadata_fetcher: ...`
  (a `module` exposing `get/1`, or a 1-arity function); otherwise the SSRF-safe
  client is used. The whole MCP surface is additionally gated by the
  off-by-default `:mcp_server` flag.
  """
  @spec fetch_client_metadata(String.t()) :: {:ok, map()} | {:error, atom() | Exception.t()}
  def fetch_client_metadata(client_id) do
    with :ok <- validate_https(client_id),
         {:ok, body} <- http_get(client_id),
         {:ok, doc} <- decode_metadata(body),
         :ok <- validate_metadata(doc, client_id) do
      {:ok, doc}
    end
  end

  defp validate_https(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host} when is_binary(host) and host != "" -> :ok
      _ -> {:error, :client_id_not_https}
    end
  end

  defp validate_https(_), do: {:error, :client_id_not_https}

  defp http_get(url) do
    case Application.get_env(:plausible, __MODULE__, [])[:client_metadata_fetcher] do
      fun when is_function(fun, 1) -> fun.(url)
      module when is_atom(module) and not is_nil(module) -> module.get(url)
      _ -> ssrf_get(url)
    end
  end

  defp ssrf_get(url) do
    case Plausible.SSRF.get(url, receive_timeout: @fetch_timeout, decode_body: false) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        if byte_size(body) > @max_metadata_bytes do
          {:error, :client_metadata_too_large}
        else
          {:ok, body}
        end

      {:ok, %Req.Response{}} ->
        {:error, :client_metadata_unavailable}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_metadata(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, doc} when is_map(doc) -> {:ok, doc}
      _ -> {:error, :invalid_client_metadata}
    end
  end

  defp decode_metadata(doc) when is_map(doc), do: {:ok, doc}
  defp decode_metadata(_), do: {:error, :invalid_client_metadata}

  @doc """
  Checks whether a requested `redirect_uri` is registered in a CIMD document's
  `redirect_uris`.

  Non-loopback URIs must match exactly. Loopback URIs (`localhost`, `127.0.0.1`,
  `[::1]`) match **ignoring the port**, per RFC 8252 section 7.3 and the MCP
  authorization spec: native clients such as Claude Code use an ephemeral
  loopback port that isn't known ahead of time, so it can't appear verbatim in
  the metadata document.
  """
  @spec redirect_uri_registered?(String.t() | nil, [String.t()]) :: boolean()
  def redirect_uri_registered?(redirect_uri, registered) when is_binary(redirect_uri) do
    redirect_uri in registered or loopback_match?(redirect_uri, registered)
  end

  def redirect_uri_registered?(_redirect_uri, _registered), do: false

  defp loopback_match?(redirect_uri, registered) do
    uri = URI.parse(redirect_uri)

    if loopback_host?(uri.host) do
      Enum.any?(registered, fn candidate ->
        registered_uri = URI.parse(candidate)

        loopback_host?(registered_uri.host) and
          registered_uri.scheme == uri.scheme and
          registered_uri.host == uri.host and
          normalize_path(registered_uri.path) == normalize_path(uri.path)
      end)
    else
      false
    end
  end

  defp loopback_host?(host), do: host in ["localhost", "127.0.0.1", "::1"]

  defp normalize_path(nil), do: "/"
  defp normalize_path(""), do: "/"
  defp normalize_path(path), do: path

  defp validate_metadata(doc, client_id) do
    redirect_uris = doc["redirect_uris"]

    cond do
      doc["client_id"] != client_id ->
        {:error, :client_id_mismatch}

      not is_list(redirect_uris) or redirect_uris == [] ->
        {:error, :missing_redirect_uris}

      not Enum.all?(redirect_uris, &is_binary/1) ->
        {:error, :invalid_redirect_uris}

      true ->
        :ok
    end
  end

  ## Cleanup

  @doc """
  Deletes expired authorization codes and fully-expired token rows. A token row
  is only removed once its refresh token has also expired (or was never issued
  and the access token has expired).
  """
  @spec delete_expired() :: %{
          authorization_codes: non_neg_integer(),
          access_tokens: non_neg_integer()
        }
  def delete_expired() do
    now = DateTime.utc_now()

    {codes, _} =
      Repo.delete_all(from(c in AuthorizationCode, where: c.expires_at < ^now))

    {tokens, _} =
      Repo.delete_all(
        from(t in AccessToken,
          where:
            t.refresh_token_expires_at < ^now or
              (is_nil(t.refresh_token_expires_at) and t.access_token_expires_at < ^now)
        )
      )

    %{authorization_codes: codes, access_tokens: tokens}
  end

  ## Helpers

  defp check_not_expired(expires_at) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
      :ok
    else
      {:error, :invalid_grant}
    end
  end

  defp match(same, same), do: :ok
  defp match(_, _), do: {:error, :invalid_grant}
end
