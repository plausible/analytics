defmodule PlausibleWeb.AuthorizeSitesApiPlug do
  import Plug.Conn
  use Plausible.Repo
  alias Plausible.Auth.ApiKey

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with {:ok, raw_api_key} <- get_bearer_token(conn),
         {:ok, api_key} <- verify_access(raw_api_key) do
      assign(conn, :current_user_id, api_key.user_id)
    else
      {:error, :missing_api_key} ->
        unauthorized(
          conn,
          "Missing API key. Please use a valid Plausible API key as a Bearer Token."
        )

      {:error, :invalid_api_key} ->
        unauthorized(
          conn,
          "Invalid API key. Please make sure you're using a valid API key with access to the site you've requested."
        )
    end
  end

  defp verify_access(api_key) do
    hashed_key = ApiKey.do_hash(api_key)
    found_key = Repo.get_by(ApiKey, key_hash: hashed_key)

    cond do
      found_key -> {:ok, found_key}
      true -> {:error, :invalid_api_key}
    end
  end

  defp get_bearer_token(conn) do
    authorization_header =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()

    case authorization_header do
      "Bearer " <> token -> {:ok, String.trim(token)}
      _ -> {:error, :missing_api_key}
    end
  end

  defp unauthorized(conn, msg) do
    conn
    |> put_status(401)
    |> Phoenix.Controller.json(%{error: msg})
    |> halt()
  end
end
