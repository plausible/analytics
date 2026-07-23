defmodule PlausibleWeb.Plugs.AuthorizeOAuthAPI do
  @moduledoc """
  Authenticates a request carrying an OAuth 2.1 Bearer access token — the
  resource-server side of the OAuth flow. Mount it on any route that should be
  accessible with an issued access token.

  Modeled on `PlausibleWeb.Plugs.AuthorizePublicAPI`: it extracts the Bearer
  token, resolves it to an `Plausible.OAuth.AccessToken` (rejecting expired
  tokens), enforces the same per-team hourly + burst rate limits, and assigns
  `:current_user`, `:current_team` and the token's granted `:oauth_scopes` for
  downstream per-scope authorization.

  On any failure it responds `401` with an RFC 9728 `WWW-Authenticate` header
  pointing clients at the Protected Resource Metadata document so they can
  (re)discover the authorization server.
  """

  use Plausible.Repo

  import Plug.Conn

  alias Plausible.Auth
  alias Plausible.OAuth
  alias Plausible.RateLimit

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, raw_token} <- get_bearer_token(conn),
         {:ok, token} <- OAuth.find_access_token(raw_token),
         {limit_key, hourly_limit} <- rate_limit_config(token),
         :ok <- check_rate_limit(limit_key, hourly_limit),
         :ok <- check_burst_limit(limit_key) do
      OAuth.mark_used(token)

      conn
      |> assign(:current_user, token.user)
      |> assign(:current_team, token.team)
      |> assign(:oauth_scopes, token.scopes)
    else
      {:error, :missing_token} -> unauthorized(conn, nil)
      {:error, :invalid_token} -> unauthorized(conn, "invalid_token")
      {:error, :rate_limit} -> too_many_requests(conn)
    end
  end

  defp rate_limit_config(%{team: %{} = team}) do
    {Auth.ApiKey.limit_key(team), team.hourly_api_request_limit}
  end

  defp check_rate_limit(limit_key, hourly_limit) do
    case RateLimit.check_rate(limit_key, to_timeout(hour: 1), hourly_limit) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limit}
    end
  end

  defp check_burst_limit(limit_key) do
    case RateLimit.check_rate(
           limit_key,
           to_timeout(second: Auth.ApiKey.burst_period_seconds()),
           Auth.ApiKey.burst_request_limit()
         ) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limit}
    end
  end

  defp get_bearer_token(conn) do
    case List.first(get_req_header(conn, "authorization")) do
      "Bearer " <> token -> {:ok, String.trim(token)}
      _ -> {:error, :missing_token}
    end
  end

  defp unauthorized(conn, error) do
    conn
    |> put_resp_header("www-authenticate", www_authenticate(error))
    |> put_status(401)
    |> Phoenix.Controller.json(%{error: error || "unauthorized"})
    |> halt()
  end

  defp too_many_requests(conn) do
    conn
    |> put_status(429)
    |> Phoenix.Controller.json(%{error: "too_many_requests"})
    |> halt()
  end

  defp www_authenticate(nil) do
    ~s(Bearer resource_metadata="#{prm_url()}")
  end

  defp www_authenticate(error) do
    ~s(Bearer resource_metadata="#{prm_url()}", error="#{error}")
  end

  defp prm_url() do
    PlausibleWeb.Endpoint.url() <> "/.well-known/oauth-protected-resource"
  end
end
