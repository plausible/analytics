defmodule PlausibleWeb.Plugs.AuthorizePluginsAPI do
  @moduledoc """
  Plug for Basic HTTP Authentication using
  Plugins API Tokens lookup.
  """

  alias PlausibleWeb.Plugins.API.Errors
  alias Plausible.Plugins.API.Tokens

  def init(opts), do: opts

  def call(conn, _opts \\ []) do
    with {:ok, token} <- extract_token(conn),
         {:ok, conn} <- authorize(conn, token) do
      conn
    end
  end

  defp authorize(conn, token_value) do
    case Tokens.find(token_value) do
      {:ok, token} ->
        {:ok, Plug.Conn.assign(conn, :authorized_site, token.site)}

      {:error, :not_found} ->
        Errors.unauthorized(conn)
    end
  end

  defp extract_token(conn) do
    case Plug.BasicAuth.parse_basic_auth(conn) do
      {_token_identifier, token_value} ->
        {:ok, token_value}

      :error ->
        Errors.unauthorized(conn)
    end
  end
end
