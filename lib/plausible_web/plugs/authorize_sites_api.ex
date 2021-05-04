defmodule PlausibleWeb.AuthorizeSitesApiPlug do
  import Plug.Conn
  use Plausible.Repo
  alias Plausible.Auth.ApiKey
  alias PlausibleWeb.Api.Helpers, as: H

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with {:ok, raw_api_key} <- get_bearer_token(conn),
         {:ok, api_key} <- verify_access(raw_api_key) do
      user = Repo.get_by(Plausible.Auth.User, id: api_key.user_id)
      assign(conn, :current_user, user)
    else
      {:error, :missing_api_key} ->
        H.unauthorized(
          conn,
          "Missing API key. Please use a valid Plausible API key as a Bearer Token."
        )

      {:error, :invalid_api_key} ->
        H.unauthorized(
          conn,
          "Invalid API key. Please make sure you're using a valid API key with access to the resource you've requested."
        )
    end
  end

  defp verify_access(api_key) do
    hashed_key = ApiKey.do_hash(api_key)

    found_key =
      Repo.one(
        from a in ApiKey,
          where: a.key_hash == ^hashed_key,
          where: fragment("? @> ?", a.scopes, ["sites:provision:*"])
      )

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
end
