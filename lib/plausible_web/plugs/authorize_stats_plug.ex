defmodule PlausibleWeb.AuthorizeStatsPlug do
  import Plug.Conn
  use Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    site = Repo.get_by(Plausible.Site, domain: conn.params["domain"])

    if !site do
      PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
    else
      user_id = get_session(conn, :current_user_id)
      shared_link_key = "shared_link_auth_" <> site.domain
      shared_link_auth = get_session(conn, shared_link_key)

      can_access =
        site.public ||
          (user_id && Plausible.Sites.is_owner?(user_id, site)) ||
          (shared_link_auth && shared_link_auth[:valid_until] > DateTime.to_unix(Timex.now()))

      if !can_access do
        PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
      else
        assign(conn, :site, site)
      end
    end
  end
end
