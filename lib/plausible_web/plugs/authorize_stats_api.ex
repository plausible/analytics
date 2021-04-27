defmodule PlausibleWeb.AuthorizeStatsApiPlug do
  import Plug.Conn
  use Plausible.Repo
  alias Plausible.Auth.ApiKey
  alias PlausibleWeb.Api.Helpers, as: H

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with {:ok, api_key} <- get_bearer_token(conn),
         {:ok, site} <- verify_access(api_key, conn.params["site_id"]) do
      assign(conn, :site, site)
    else
      {:error, :missing_api_key} ->
        H.unauthorized(
          conn,
          "Missing API key. Please use a valid Plausible API key as a Bearer Token."
        )

      {:error, :missing_site_id} ->
        H.bad_request(
          conn,
          "Missing site ID. Please provide the required site_id parameter with your request."
        )

      {:error, :invalid_api_key} ->
        H.unauthorized(
          conn,
          "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
        )
    end
  end

  defp verify_access(_api_key, nil), do: {:error, :missing_site_id}

  defp verify_access(api_key, site_id) do
    hashed_key = ApiKey.do_hash(api_key)
    found_key = Repo.get_by(ApiKey, key_hash: hashed_key)
    site = Repo.get_by(Plausible.Site, domain: site_id)
    is_owner = site && found_key && Plausible.Sites.is_owner?(found_key.user_id, site)

    cond do
      found_key && site && is_owner -> {:ok, site}
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
