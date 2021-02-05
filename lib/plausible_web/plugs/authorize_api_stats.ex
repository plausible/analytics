defmodule PlausibleWeb.AuthorizeApiStatsPlug do
  import Plug.Conn
  use Plausible.Repo
  alias Plausible.Auth.ApiKey

  def init(options) do
    options
  end

  def call(conn, _opts) do
    site = Repo.get_by(Plausible.Site, domain: conn.params["site_id"])
    api_key = get_bearer_token(conn)

    if !(site && api_key) do
      not_found(conn)
    else
      hashed_key = ApiKey.do_hash(api_key)
      found_key = Repo.get_by(ApiKey, key_hash: hashed_key)
      can_access = found_key && Plausible.Sites.is_owner?(found_key.user_id, site)

      if !can_access do
        not_found(conn)
      else
        assign(conn, :site, site)
      end
    end
  end

  defp get_bearer_token(conn) do
    authorization_header =
      Plug.Conn.get_req_header(conn, "authorization")
      |> List.first()

    case authorization_header do
      "Bearer " <> token -> String.trim(token)
      _ -> nil
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(404)
    |> Phoenix.Controller.json(%{error: "Not found"})
    |> halt()
  end
end
