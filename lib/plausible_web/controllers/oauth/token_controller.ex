defmodule PlausibleWeb.OAuth.TokenController do
  @moduledoc """
  OAuth 2.1 token endpoint. Public client (PKCE, no client authentication).
  """

  use PlausibleWeb, :controller

  @doc """
  Exchanges an authorization code or a refresh token for an access token at the
  [token endpoint](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-token-endpoint).
  """
  def token(conn, _params) do
    conn
    |> put_status(501)
    |> json(%{error: "not_implemented"})
  end
end
