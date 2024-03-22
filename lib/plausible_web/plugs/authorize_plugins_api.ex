defmodule PlausibleWeb.Plugs.AuthorizePluginsAPI do
  @moduledoc """
  Plug for Basic HTTP Authentication using
  Plugins API Tokens lookup.
  """

  alias PlausibleWeb.Plugins.API.Errors
  alias Plausible.Plugins.API.Tokens
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts \\ []) do
    send_error? =
      Keyword.get(opts, :send_error?, true)

    with {:ok, token} <- extract_token(conn),
         {:ok, conn} <- authorize(conn, token) do
      conn
    else
      {:unauthorized, conn} ->
        if send_error? do
          Errors.unauthorized(conn)
        else
          conn
        end
    end
  end

  defp authorize(conn, token_value) do
    case Tokens.find(token_value) do
      {:ok, token} ->
        {:ok, token} = Tokens.update_last_seen(token)
        {:ok, Plug.Conn.assign(conn, :authorized_site, token.site)}

      {:error, :not_found} ->
        {:unauthorized, conn}
    end
  end

  defp extract_token(conn) do
    with ["Basic " <> encoded_user_and_pass] <- get_req_header(conn, "authorization"),
         {:ok, decoded_user_and_pass} <- Base.decode64(encoded_user_and_pass) do
      case :binary.split(decoded_user_and_pass, ":") do
        [_user, token_value] -> {:ok, token_value}
        [token_value] -> {:ok, token_value}
      end
    else
      _ ->
        {:unauthorized, conn}
    end
  end
end
