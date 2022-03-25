defmodule PlausibleWeb.AuthorizeStatsApiPlug do
  import Plug.Conn
  use Plausible.Repo
  alias Plausible.Auth.ApiKey
  alias PlausibleWeb.Api.Helpers, as: H

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with {:ok, token} <- get_bearer_token(conn),
         {:ok, api_key} <- find_api_key(token),
         :ok <- check_api_key_rate_limit(api_key),
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

      {:error, :rate_limit, limit} ->
        H.too_many_requests(
          conn,
          "Too many API requests. Your API key is limited to #{limit} requests per hour."
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
    site = Repo.get_by(Plausible.Site, domain: site_id)
    is_member = site && Plausible.Sites.is_member?(api_key.user_id, site)
    is_super_admin = Plausible.Auth.is_super_admin?(api_key.user_id)

    cond do
      site && is_member -> {:ok, site}
      site && is_super_admin -> {:ok, site}
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

  defp find_api_key(token) do
    hashed_key = ApiKey.do_hash(token)
    found_key = Repo.get_by(ApiKey, key_hash: hashed_key)
    if found_key, do: {:ok, found_key}, else: {:error, :invalid_api_key}
  end

  @one_hour 60 * 60 * 1000
  defp check_api_key_rate_limit(api_key) do
    case Hammer.check_rate("api_request:#{api_key.id}", @one_hour, api_key.hourly_request_limit) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limit, api_key.hourly_request_limit}
    end
  end
end
