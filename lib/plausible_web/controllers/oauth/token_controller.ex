defmodule PlausibleWeb.OAuth.TokenController do
  @moduledoc """
  OAuth 2.1 token endpoint. Public client (PKCE, no client authentication).

  Supports the `authorization_code` and `refresh_token` grants. All errors are
  returned as `{error, error_description}` JSON with the appropriate status.
  """

  use PlausibleWeb, :controller

  alias Plausible.OAuth

  def token(conn, %{"grant_type" => "authorization_code"} = params) do
    with {:ok, code} <- require_param(params, "code"),
         {:ok, verifier} <- require_param(params, "code_verifier"),
         {:ok, redirect_uri} <- require_param(params, "redirect_uri"),
         {:ok, auth_code} <-
           OAuth.consume_authorization_code(
             code,
             verifier,
             redirect_uri,
             params["resource"]
           ),
         {:ok, tokens} <- OAuth.issue_tokens(auth_code) do
      send_tokens(conn, tokens)
    else
      {:error, :missing_param, name} ->
        send_error(conn, 400, "invalid_request", "Missing required parameter: #{name}")

      {:error, _} ->
        send_error(conn, 400, "invalid_grant", "The authorization code is invalid or expired")
    end
  end

  def token(conn, %{"grant_type" => "refresh_token"} = params) do
    with {:ok, refresh_token} <- require_param(params, "refresh_token"),
         {:ok, tokens} <- OAuth.refresh_tokens(refresh_token) do
      send_tokens(conn, tokens)
    else
      {:error, :missing_param, name} ->
        send_error(conn, 400, "invalid_request", "Missing required parameter: #{name}")

      {:error, _} ->
        send_error(conn, 400, "invalid_grant", "The refresh token is invalid or expired")
    end
  end

  def token(conn, %{"grant_type" => grant_type}) do
    send_error(
      conn,
      400,
      "unsupported_grant_type",
      "Unsupported grant_type: #{grant_type}"
    )
  end

  def token(conn, _params) do
    send_error(conn, 400, "invalid_request", "Missing required parameter: grant_type")
  end

  defp send_tokens(conn, tokens) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("pragma", "no-cache")
    |> json(tokens)
  end

  defp require_param(params, name) do
    case params[name] do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_param, name}
    end
  end

  defp send_error(conn, status, error, description) do
    conn
    |> put_status(status)
    |> json(%{error: error, error_description: description})
  end
end
