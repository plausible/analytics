defmodule PlausibleWeb.Plugs.AuthorizeOAuthAPI do
  @moduledoc """
  Plug for authorizing requests that carry an OAuth 2.1 Bearer access token.

  Modeled on `PlausibleWeb.Plugs.AuthorizePublicAPI`.

  Assigns
  - `:current_user`,
  - `:current_team`
  - `:current_team_role`
  - `:oauth_scopes`

  A failure answers `401` with a
  [`WWW-Authenticate` header](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-the-www-authenticate-respon)
  pointing at the Protected Resource Metadata document, which is how a client
  discovers which authorization server to use.
  """

  import Plug.Conn

  alias Plausible.OAuth
  alias Plausible.OAuth.ProtectedResources
  alias PlausibleWeb.Api.Helpers, as: H
  alias PlausibleWeb.Api.RateLimit
  use PlausibleWeb.VerifiedRoutes

  def init(opts), do: opts

  def call(conn, opts) do
    resource = Keyword.fetch!(opts, :resource)

    with {:ok, raw_token} <- get_bearer_token(conn),
         {:ok, grant, role} <- OAuth.find_access_token(raw_token, resource),
         :ok <- check_rate_limit(grant.team) do
      conn
      |> assign(:current_user, grant.user)
      |> assign(:current_team, grant.team)
      |> assign(:current_team_role, role)
      |> assign(:oauth_scopes, grant.scopes)
    else
      {:error, :missing_token} ->
        conn
        |> put_resp_header("www-authenticate", challenge(resource))
        |> H.unauthorized("unauthorized")

      {:error, :invalid_token} ->
        conn
        |> put_resp_header(
          "www-authenticate",
          challenge(resource) <> ~s(, error="invalid_token")
        )
        |> H.unauthorized("invalid_token")

      {:error, :rate_limit, _message} ->
        H.too_many_requests(conn, "too_many_requests")
    end
  end

  defp get_bearer_token(conn) do
    case List.first(get_req_header(conn, "authorization")) do
      "Bearer " <> token -> {:ok, String.trim(token)}
      _ -> {:error, :missing_token}
    end
  end

  defp check_rate_limit(team) do
    RateLimit.check_rate_limit(RateLimit.limit_key(team), team.hourly_api_request_limit)
  end

  @doc """
  Builds the `WWW-Authenticate` challenge for a request refused because its token
  does not carry `scope`. See [runtime insufficient scope errors](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization#runtime-insufficient-scope-errors).

  ## Examples
  iex> challenge(Plausible.OAuth.ProtectedResources.mcp(), "sites:read:*")
  ~s(Bearer resource_metadata="http://localhost:8000/.well-known/oauth-protected-resource/mcp", scope="sites:read:*", error="insufficient_scope")
  """
  @spec challenge(ProtectedResources.t(), String.t()) :: String.t()
  def challenge(resource, scope),
    do: challenge(resource) <> ~s(, scope="#{scope}", error="insufficient_scope")

  defp challenge(resource),
    do: ~s(Bearer resource_metadata="#{resource_metadata_url(resource)}")

  defp resource_metadata_url(resource) do
    "#{PlausibleWeb.Endpoint.url()}/.well-known/oauth-protected-resource" <>
      resource.resource_path
  end
end
