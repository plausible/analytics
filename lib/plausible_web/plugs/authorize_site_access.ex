defmodule PlausibleWeb.AuthorizeSiteAccess do
  import Plug.Conn
  use Plausible.Repo

  def init([]), do: [:public, :viewer, :admin, :super_admin, :owner]
  def init(allowed_roles), do: allowed_roles

  def call(conn, allowed_roles) do
    site =
      Repo.get_by(Plausible.Site,
        domain: conn.path_params["domain"] || conn.path_params["website"]
      )

    shared_link_auth = conn.params["auth"]

    shared_link_record =
      shared_link_auth && Repo.get_by(Plausible.Site.SharedLink, slug: shared_link_auth)

    if !site do
      PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
    else
      user_id = get_session(conn, :current_user_id)
      membership_role = user_id && Plausible.Sites.role(user_id, site)

      role =
        cond do
          user_id && membership_role ->
            membership_role

          Plausible.Auth.is_super_admin?(user_id) ->
            :super_admin

          site.public ->
            :public

          shared_link_record && shared_link_record.site_id == site.id ->
            :public

          true ->
            nil
        end

      if role in allowed_roles do
        Sentry.Context.set_user_context(%{id: user_id})
        Plausible.OpenTelemetry.add_user_attributes(user_id)

        Sentry.Context.set_extra_context(%{site_id: site.id, domain: site.domain})
        Plausible.OpenTelemetry.add_site_attributes(site)

        merge_assigns(conn, site: site, current_user_role: role)
      else
        PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
      end
    end
  end
end
