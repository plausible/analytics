defmodule PlausibleWeb.OAuth.TokenController do
  @moduledoc """
  OAuth 2.1 token endpoint. Public client (PKCE, no client authentication).
  """

  use PlausibleWeb, :controller

  alias Plausible.OAuth

  @doc """
  Exchanges an authorization code or a refresh token for an access token at the
  [token endpoint](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-token-endpoint).
  """
  def token(conn, _params) do
    if client_authentication_attempted?(conn) do
      send_error(conn, "invalid_request")
    else
      grant(conn)
    end
  end

  defp client_authentication_attempted?(conn) do
    get_req_header(conn, "authorization") != []
  end

  defp grant(%Plug.Conn{body_params: %{"grant_type" => "authorization_code"} = params} = conn) do
    with {:ok, code} <- require_param(params, "code"),
         {:ok, verifier} <- require_param(params, "code_verifier"),
         {:ok, redirect_uri} <- require_param(params, "redirect_uri"),
         {:ok, client_id} <- require_param(params, "client_id"),
         {:ok, resource} <- require_param(params, "resource"),
         {:ok, auth_code} <-
           OAuth.consume_authorization_code(code, %{
             verifier: verifier,
             client_id: client_id,
             redirect_uri: redirect_uri,
             resource: resource
           }),
         {:ok, token} <- OAuth.issue_token(auth_code) do
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("pragma", "no-cache")
      |> json(token)
    else
      {:error, :missing_param, _name} ->
        send_error(conn, "invalid_request")

      {:error, _} ->
        send_error(conn, "invalid_grant")
    end
  end

  defp grant(%Plug.Conn{body_params: %{"grant_type" => _unsupported_grant_type}} = conn) do
    send_error(conn, "unsupported_grant_type")
  end

  defp grant(conn) do
    send_error(conn, "invalid_request")
  end

  defp require_param(params, name) do
    case params[name] do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_param, name}
    end
  end

  defp send_error(conn, error) do
    conn
    |> put_status(400)
    |> json(%{error: error})
  end
end
