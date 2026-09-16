defmodule PlausibleWeb.OAuth.AuthorizeController do
  @moduledoc """
  OAuth 2.1 authorization module.
  """

  use PlausibleWeb, :controller

  @doc """
  Validates an incoming [authorization request](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-authorization-request)
  and renders the consent screen for the logged-in user.
  """
  def authorize_form(conn, _params) do
    not_implemented(conn)
  end

  @doc """
  Turns the user's approve/deny decision into an
  [authorization response](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#name-authorization-response),
  redirecting back to the client with a code or an error.
  """
  def authorize(conn, _params) do
    not_implemented(conn)
  end

  defp not_implemented(conn) do
    conn
    |> put_status(501)
    |> json(%{error: "not_implemented"})
  end
end
