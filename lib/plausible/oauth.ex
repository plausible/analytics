defmodule Plausible.OAuth do
  @moduledoc """
  Minimal OAuth 2.1 authorization server used to authenticate remote MCP
  connectors (e.g. Claude) against Plausible.

  Client registration is **CIMD-only** (Client ID Metadata Documents): the
  `client_id` is an HTTPS URL pointing at a JSON metadata document the server
  fetches at authorize-time. There is no Dynamic Client Registration endpoint
  and no clients table.

  Security invariants enforced here:

    * PKCE with `S256` is mandatory; `plain` is rejected.
    * Authorization codes are single-use and short-lived.
    * The `resource` ([RFC 8707](https://www.rfc-editor.org/rfc/rfc8707.html)) is
      threaded authorize -> code -> token so access tokens are audience-bound.
    * Only hashes of codes and tokens are persisted, never the raw values.
    * The CIMD fetch goes through an SSRF-guarded HTTP client.
    * The scopes and team recorded on a code or grant are a ceiling taken from
      the consent decision, re-checked against live team membership every time
      they are used - see `effective_scopes/1`.

  Only the `authorization_code` grant is implemented at the token endpoint;
  redeeming a refresh token is not wired up yet.
  """

  use Plausible.Repo

  alias Plausible.OAuth.{AuthorizationCode, Grant, Token, ProtectedResources}

  # TTLs (in seconds)
  @authorization_code_ttl 600
  @access_token_ttl 3600
  @refresh_token_ttl 30 * 24 * 3600

  @fetch_timeout 5_000
  @max_metadata_bytes 1_000_000
  @max_client_name_length 255
  @max_client_id_length 2048
  @max_redirect_uri_length 2048

  # RFC 7636 section 4.1. The floor matters as much as the ceiling: the digest of
  # a short or empty verifier is guessable, which reduces PKCE to a no-op.
  @code_verifier_min_length 43
  @code_verifier_max_length 128

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
  Normalizes the `resource` request parameter
  ([RFC 8707](https://www.rfc-editor.org/rfc/rfc8707.html)) against the
  protected resources this server issues tokens for.

  Returns the resource itself rather than its identifier, because it decides the
  question that follows: which scopes may be granted for it.
  """
  @spec normalize_resource(String.t() | nil) ::
          {:ok, ProtectedResources.t()} | {:error, :invalid_target}
  def normalize_resource(resource) do
    case ProtectedResources.get_by_url(resource) do
      {:ok, protected_resource} -> {:ok, protected_resource}
      {:error, :not_found} -> {:error, :invalid_target}
    end
  end

  @doc """
  Normalizes a space-delimited `scope` request parameter against the scopes the
  given resource supports.

  Scopes are validated per resource, not globally, which is what stops a token
  minted for one resource carrying authority over another.

  An absent or empty parameter defaults to all of the resource's scopes (RFC 6749
  §3.3 pre-defined default). A non-empty parameter naming any scope the resource
  does not support is rejected with `{:error, :invalid_scope}` (RFC 6749 §4.1.2.1)
  rather than silently dropping the unknown entries. The result follows the
  resource's own `:scopes_supported` order.

  Only for values arriving from a request: reading an absent value as "every
  scope on offer" is wrong for anything already decided, so reach for
  `normalize_granted_scopes/2` there.
  """
  @spec normalize_requested_scopes(String.t() | nil, ProtectedResources.t()) ::
          {:ok, [String.t()]} | {:error, :invalid_scope}
  def normalize_requested_scopes(scope, resource) when is_nil(scope) or is_binary(scope) do
    case String.split(scope || "", " ", trim: true) do
      [] -> {:ok, resource.scopes_supported}
      requested -> normalize_granted_scopes(requested, resource)
    end
  end

  def normalize_requested_scopes(_scope, _resource), do: {:error, :invalid_scope}

  @doc """
  Normalizes an explicit set of scopes - one already decided on rather than one
  being asked for - against the scopes the given resource supports.

  Takes a non-empty list; there is no default here, so no path through this
  function can widen a scope set, and no authorization can be created holding
  none. A list naming any unsupported scope is rejected whole, and the result
  follows the resource's own `:scopes_supported` order.

  Rejecting an unsupported scope outright is what a grant still being decided
  deserves. Once one exists, a scope since withdrawn from the resource narrows it
  instead - see `effective_scopes/1`.
  """
  @spec normalize_granted_scopes([String.t()], ProtectedResources.t()) ::
          {:ok, [String.t()]} | {:error, :invalid_scope}
  def normalize_granted_scopes(scopes, resource) when is_list(scopes) and scopes != [] do
    supported = resource.scopes_supported

    if Enum.all?(scopes, &(&1 in supported)) do
      {:ok, Enum.filter(supported, &(&1 in scopes))}
    else
      {:error, :invalid_scope}
    end
  end

  def normalize_granted_scopes(_scopes, _resource), do: {:error, :invalid_scope}

  @doc """
  Resolves what a stored authorization is worth *now*, as opposed to what it was
  worth when the user approved it.

  The `scopes`, `team_id` and `resource` recorded on an authorization code or a
  grant are a ceiling taken from the consent decision, not a statement of
  authority. Either half can go stale while the authorization is outstanding: the
  user can be removed from the team it is bound to, and a scope can be withdrawn
  from the resource's `:scopes_supported` in a deploy.

  Returns the scopes that survive intersecting that ceiling with what may
  currently be granted to this user for this resource. Narrowing, not validating:
  a grant that already exists has to be read for whatever is left of it.

  `{:error, :stale_authorization}` means nothing is left under the ceiling: the
  resource no longer exists, every granted scope has been withdrawn, or the user
  is no longer a member of the team. The empty scope list is refused rather than
  returned, because a credential that authenticates while authorizing nothing
  invites downstream code to read the presence of a grant as permission.

  Team membership is the only live entitlement checked here, and every role
  counts as membership, guests included. Scopes are deliberately coarse and
  resource-wide, which leaves *which sites* a member may read to the site-level
  authorization that already answers it from live state on every query.
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

  `:resource` and `:scopes` are resolved here rather than trusted from the
  caller: the authorize form answered the same two questions to render the
  consent screen, but this is a separate request carrying separate parameters.
  The grant opened by `issue_token/1` inherits both from the code.

  Returns the raw code to hand to the client - only its hash is stored, so this
  is the only point where the raw value exists.
  """
  @spec create_authorization_code(Plausible.Auth.User.t(), Plausible.Teams.Team.t(), map()) ::
          {:ok, String.t()} | {:error, Ecto.Changeset.t() | :invalid_scope | :invalid_target}
  def create_authorization_code(user, team, attrs) do
    with {:ok, resource} <- normalize_resource(attrs[:resource]),
         {:ok, scopes} <- normalize_granted_scopes(attrs[:scopes], resource) do
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

  `:client_id` matters even though PKCE already proves possession of the
  verifier - [OAuth 2.1 §4.1.3](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-token-endpoint-extension)
  requires the server to confirm the code was issued to the client redeeming it.

  The row is deleted on lookup regardless of whether the subsequent checks pass,
  so a code can only ever be redeemed once - a replay finds nothing.

  Beyond the presented values, `effective_scopes/1` must still return exactly the
  scopes the user approved, so a code outlives neither the user's membership of
  the bound team nor the scopes it names.
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
           verify_pkce(
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

  # Narrowing to the surviving scopes would be defensible (RFC 6749 section 3.3),
  # but a withdrawn scope is a deliberate kill switch, so re-consent is the
  # honest outcome: the grant is what is no longer valid, not the request.
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
  Opens a grant from a consumed authorization code, inheriting its client,
  scopes, resource, user and team.

  Issues an access token and a refresh token together; both raw values are
  returned once here and only their hashes are kept.
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

  `resource` is the protected resource the token is being presented to, and a
  grant minted for a different one is not found. Taking it as an argument rather
  than leaving the check to the caller is what makes the binding unskippable
  ([RFC 8707](https://www.rfc-editor.org/rfc/rfc8707.html)): there is no arity
  that answers "is this token live?" without also answering "was it issued for
  here?".

  The audience sits in the query alongside expiry and revocation because it is
  the same class of condition - the token exists but is not usable here - and,
  per [RFC 6750 section 3.1](https://www.rfc-editor.org/rfc/rfc6750.html#section-3.1),
  all three are answered with the same `invalid_token`.
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
  Revokes a grant, invalidating both of its tokens from the next use on.

  Recorded on the row rather than deleted, so a revoked connection can still be
  displayed as revoked and its `previous_refresh_token_hash` still recognised on
  replay. Idempotent: an already-revoked grant keeps its original `revoked_at`.

  This is the reaction a refresh request owes a stale authorization once the
  refresh grant is wired up, and the hook for revoking on the change itself - a
  membership removed, a role downgraded, a team deleted.
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

  @doc """
  Verifies a PKCE code verifier against a stored challenge. Only `S256` is
  accepted; `plain` and unknown methods are rejected.

  The verifier is refused unless it is #{@code_verifier_min_length}-#{@code_verifier_max_length}
  characters long ([RFC 7636 section 4.1](https://www.rfc-editor.org/rfc/rfc7636.html#section-4.1)),
  checked before the digest is computed so an out-of-range value costs no hash.
  """
  @spec verify_pkce(String.t(), String.t() | nil, String.t()) :: :ok | {:error, :invalid_grant}
  def verify_pkce(challenge, verifier, "S256")
      when is_binary(challenge) and is_binary(verifier) and
             byte_size(verifier) >= @code_verifier_min_length and
             byte_size(verifier) <= @code_verifier_max_length do
    computed = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    if Plug.Crypto.secure_compare(computed, challenge) do
      :ok
    else
      {:error, :invalid_grant}
    end
  end

  def verify_pkce(_challenge, _verifier, _method), do: {:error, :invalid_grant}

  @doc """
  Fetches and validates a Client ID Metadata Document.

  `client_id` MUST be the HTTPS URL of the document, with a path component and
  carrying no userinfo, no fragment and no dot segments
  ([CIMD](https://datatracker.ietf.org/doc/draft-ietf-oauth-client-id-metadata-document/)
  section 3). The fetched document is validated to be self-referential (its
  `client_id` equals the requested URL), to declare at least one `redirect_uris`
  entry, and to carry a `client_name` that is displayable and storable if it
  declares one at all.

  This performs a server-side GET against an attacker-influenced URL, so host
  and IP filtering is delegated to the shared `Plausible.SSRF` helper rather than
  hand-rolled here. Request options are extendable via
  `config :plausible, Plausible.OAuth, req_opts: [...]`, which is how tests point
  the fetch at `Req.Test`.
  """
  @spec fetch_client_metadata(String.t()) :: {:ok, map()} | {:error, atom() | Exception.t()}
  def fetch_client_metadata(client_id) do
    with :ok <- validate_client_id(client_id),
         {:ok, body} <- ssrf_get(client_id),
         {:ok, doc} <- decode_metadata(body),
         :ok <- validate_metadata(doc, client_id) do
      {:ok, doc}
    end
  end

  # Checked before the fetch, so an absurd client_id costs no DNS lookup.
  #
  # Every rule here defends the same thing: the client_id is displayed on the
  # consent screen and stored on every code and grant it issues, so one document
  # must have exactly one identity, and that identity must read as the host it
  # is fetched from. Userinfo breaks the second - `https://claude.ai@evil.example/meta`
  # fetches from evil.example while reading as Claude - and a fragment, a missing
  # path or a dot segment break the first.
  defp validate_client_id(url) when is_binary(url) and byte_size(url) > @max_client_id_length do
    {:error, :client_id_too_long}
  end

  defp validate_client_id(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, userinfo: nil, fragment: nil, path: path}
      when is_binary(host) and host != "" and is_binary(path) and path != "" ->
        if dot_segments?(path), do: {:error, :invalid_client_id}, else: :ok

      %URI{scheme: "https", host: host} when is_binary(host) and host != "" ->
        {:error, :invalid_client_id}

      _ ->
        {:error, :client_id_not_https}
    end
  end

  defp validate_client_id(_), do: {:error, :client_id_not_https}

  # A whole segment, not a dot anywhere: ".well-known" and a ".json" extension
  # are both legitimate, while "/a/../meta" and "/meta" are one document under
  # two identities - and the identity is what is stored and displayed.
  #
  # "%2e" counts, because RFC 3986 section 6.2.2.2 makes it the same segment. Only
  # that one escape is folded, rather than decoding the whole path, so a malformed
  # escape stays a client error here instead of raising out of `URI.decode/1`.
  defp dot_segments?(path) do
    path
    |> String.split("/")
    |> Enum.any?(fn segment ->
      String.replace(String.downcase(segment), "%2e", ".") in [".", ".."]
    end)
  end

  defp ssrf_get(url) do
    opts =
      [receive_timeout: @fetch_timeout, decode_body: false]
      |> Keyword.merge(Application.get_env(:plausible, __MODULE__, [])[:req_opts] || [])

    case Plausible.SSRF.get(url, opts) do
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

  defp decode_metadata(body) do
    case JSON.decode(body) do
      {:ok, doc} when is_map(doc) -> {:ok, doc}
      _ -> {:error, :invalid_client_metadata}
    end
  end

  defp validate_metadata(doc, client_id) do
    redirect_uris = doc["redirect_uris"]

    cond do
      doc["client_id"] != client_id -> {:error, :client_id_mismatch}
      not is_list(redirect_uris) or redirect_uris == [] -> {:error, :missing_redirect_uris}
      not Enum.all?(redirect_uris, &valid_redirect_uri?/1) -> {:error, :invalid_redirect_uris}
      not valid_client_name?(doc["client_name"]) -> {:error, :invalid_client_name}
      true -> :ok
    end
  end

  # A redirect_uri is a navigation target handed to the user's browser after
  # consent, so its scheme is a security boundary: `javascript:` and `data:`
  # execute on *this* origin the moment anything renders the value as a link.
  #
  # Only the three shapes RFC 8252 section 7 defines for a native client are
  # accepted: a claimed `https` URL, `http` on a loopback host (section 7.3),
  # and a private-use scheme, which section 7.1 says is a domain name written in
  # reverse - so it contains a dot, which `javascript`, `data`, `file` and
  # `vbscript` do not. Fragments are forbidden by OAuth 2.1 section 2.3, and the
  # length bound is the one the destination column allows, so an over-long entry
  # fails here rather than after the user has approved.
  defp valid_redirect_uri?(uri)
       when is_binary(uri) and byte_size(uri) <= @max_redirect_uri_length do
    case URI.parse(uri) do
      %URI{fragment: fragment} when not is_nil(fragment) -> false
      %URI{scheme: "https", host: host} -> is_binary(host) and host != ""
      %URI{scheme: "http", host: host} -> loopback_host?(host)
      %URI{scheme: scheme} when is_binary(scheme) -> String.contains?(scheme, ".")
      _ -> false
    end
  end

  defp valid_redirect_uri?(_uri), do: false

  # An absent client_name is fine - the consent screen falls back to the
  # client_id - but a blank one is not: `"" || client_id` is `""` in Elixir, so
  # it blanks the identity line without triggering that fallback.
  defp valid_client_name?(nil), do: true

  defp valid_client_name?(name) when is_binary(name) do
    String.trim(name) != "" and
      String.length(name) <= @max_client_name_length and
      not unreadable?(name)
  end

  defp valid_client_name?(_), do: false

  # Only about what the user reads on the consent screen - HEEx escapes the value
  # either way. Controls (C0, DEL, C1) truncate or garble the identity line, and
  # the bidi overrides U+202A-U+202E and isolates U+2066-U+2069 reorder the
  # glyphs around them, so a name can be made to render as a different one.
  defp unreadable?(name) do
    name
    |> String.to_charlist()
    |> Enum.any?(fn codepoint ->
      codepoint <= 0x1F or codepoint in 0x7F..0x9F or
        codepoint in 0x202A..0x202E or codepoint in 0x2066..0x2069
    end)
  end

  @doc """
  Checks whether a requested `redirect_uri` is registered in a CIMD document's
  `redirect_uris`.

  Non-loopback URIs must match exactly. For loopback URIs (`localhost`,
  `127.0.0.1`, `[::1]`) the port - and *only* the port - is allowed to differ,
  per [OAuth 2.1 §2.3.1](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-registration-requirements)
  and [RFC 8252 §7.3](https://www.rfc-editor.org/rfc/rfc8252.html#section-7.3):
  a native client binds an ephemeral port it cannot know ahead of time, so the
  port cannot appear verbatim in the metadata document. Every other component
  still has to match exactly, so a registered loopback URI cannot be turned into
  a different endpoint by appending a query string.
  """
  @spec redirect_uri_registered?(String.t() | nil, [String.t()]) :: boolean()
  def redirect_uri_registered?(redirect_uri, registered) when is_binary(redirect_uri) do
    redirect_uri in registered or loopback_match?(redirect_uri, registered)
  end

  def redirect_uri_registered?(_redirect_uri, _registered), do: false

  defp loopback_match?(redirect_uri, registered) do
    uri = URI.parse(redirect_uri)

    loopback_host?(uri.host) and
      Enum.any?(registered, fn candidate ->
        registered_uri = URI.parse(candidate)

        loopback_host?(registered_uri.host) and equal_but_for_port?(registered_uri, uri)
      end)
  end

  # Case-folded because RFC 3986 section 3.2.2 makes the host case-insensitive,
  # so `LOCALHOST` names the same interface as `localhost`.
  defp loopback_host?(host), do: downcase(host) in ["localhost", "127.0.0.1", "::1"]

  # Component-wise rather than struct equality: `URI.parse/1` also populates the
  # deprecated `:authority`, which embeds the port. Scheme and host are
  # case-folded (RFC 3986 sections 3.1 and 3.2.2); the rest are case-sensitive.
  defp equal_but_for_port?(%URI{} = a, %URI{} = b) do
    downcase(a.scheme) == downcase(b.scheme) and
      a.userinfo == b.userinfo and
      downcase(a.host) == downcase(b.host) and
      normalize_path(a.path) == normalize_path(b.path) and
      a.query == b.query and
      a.fragment == b.fragment
  end

  defp normalize_path(nil), do: "/"
  defp normalize_path(""), do: "/"
  defp normalize_path(path), do: path

  defp downcase(nil), do: nil
  defp downcase(value), do: String.downcase(value)

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
