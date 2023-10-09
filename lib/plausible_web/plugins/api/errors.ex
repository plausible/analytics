defmodule PlausibleWeb.Plugins.API.Errors do
  @moduledoc """
  Common responses for Plugins API
  """

  import Plug.Conn
  import Plausible.ChangesetHelpers

  @spec unauthorized(Plug.Conn.t()) :: Plug.Conn.t()
  def unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", ~s[Basic realm="Plugins API Access"])
    |> error(:unauthorized, "Plugins API: unauthorized")
  end

  @spec error(
          Plug.Conn.t(),
          Plug.Conn.status(),
          String.t() | [String.t()] | Ecto.Changeset.t() | [Ecto.Changeset.t()]
        ) ::
          Plug.Conn.t()
  def error(conn, status, message) when is_binary(message) do
    error(conn, status, [message])
  end

  def error(conn, status, message) when is_map(message) do
    error(conn, status, [message])
  end

  def error(conn, status, messages) when is_list(messages) do
    response =
      Jason.encode!(%{
        errors:
          Enum.map(messages, fn
            message when is_binary(message) ->
              %{detail: message}

            %Ecto.Changeset{} = changeset ->
              changeset
              |> traverse_errors()
              |> Enum.map(fn {key, message} ->
                %{detail: "#{key}: #{message}"}
              end)
          end)
          |> List.flatten()
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, response)
    |> halt()
  end
end
