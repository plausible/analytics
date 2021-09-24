defmodule PlausibleWeb.AuthorizeSiteAccess do
  import Plug.Conn
  use Plausible.Repo

  def init([]), do: [:public, :viewer, :admin, :owner]
  def init(allowed_roles), do: allowed_roles

  defp get_site_and_role(domain, nil) do
    site = Repo.get_by(Plausible.Site, domain: domain)
    {site, nil}
  end

  defp get_site_and_role(domain, user_id) do
    Repo.one(
      from s in Plausible.Site,
        left_join: sm in Plausible.Site.Membership,
        on: sm.site_id == s.id,
        where: s.domain == ^domain,
        where: sm.user_id == ^user_id or s.public,
        select: {s, sm.role}
    ) || {nil, nil}
  end

  def call(conn, allowed_roles) do
    domain = conn.params["domain"] || conn.params["website"]
    user_id = get_session(conn, :current_user_id)
    {site, membership_role} = get_site_and_role(domain, user_id)

    shared_link_auth = conn.params["auth"]

    shared_link_record =
      shared_link_auth && Repo.get_by(Plausible.Site.SharedLink, slug: shared_link_auth)

    if !site do
      PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
    else
      role =
        cond do
          user_id && membership_role ->
            membership_role

          site.public ->
            :public

          shared_link_record && shared_link_record.site_id == site.id ->
            :public

          user_id in admin_user_ids() ->
            :admin

          true ->
            nil
        end

      if role in allowed_roles do
        merge_assigns(conn, site: site, current_user_role: role)
      else
        PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
      end
    end
  end

  defp admin_user_ids() do
    Application.get_env(:plausible, :admin_user_ids)
  end
end
