defmodule PlausibleWeb.Plugs.AuthorizeSiteAccess do
  @moduledoc """
  Plug restricting access to site and shared link, when present.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [get_format: 1]
  use Plausible.Repo

  def init([]), do: [:public, :viewer, :admin, :super_admin, :owner]
  def init(allowed_roles), do: allowed_roles

  def call(conn, allowed_roles) do
    current_user = conn.assigns[:current_user]

    with {:ok, site} <- get_site(conn),
         {:ok, shared_link} <- maybe_get_shared_link(conn, site) do
      membership_role = get_membership_role(current_user, site)

      role =
        cond do
          membership_role ->
            membership_role

          Plausible.Auth.is_super_admin?(current_user) ->
            :super_admin

          site.public ->
            :public

          shared_link ->
            :public

          true ->
            nil
        end

      if role in allowed_roles do
        if current_user do
          Sentry.Context.set_user_context(%{id: current_user.id})
          Plausible.OpenTelemetry.add_user_attributes(current_user.id)
        end

        Sentry.Context.set_extra_context(%{site_id: site.id, domain: site.domain})
        Plausible.OpenTelemetry.add_site_attributes(site)

        site = Plausible.Imported.load_import_data(site)

        merge_assigns(conn, site: site, current_user_role: role)
      else
        error_not_found(conn)
      end
    end
  end

  defp get_site(conn) do
    domain = conn.path_params["domain"] || conn.path_params["website"] || conn.params["site_id"]

    if site = Repo.get_by(Plausible.Site, domain: domain) do
      {:ok, site}
    else
      error_not_found(conn)
    end
  end

  defp maybe_get_shared_link(conn, site) do
    slug = conn.params["slug"] || conn.params["auth"]
    site_id = site.id

    if is_binary(slug) do
      case Repo.get_by(Plausible.Site.SharedLink, slug: slug) do
        %{site_id: ^site_id} = shared_link -> {:ok, shared_link}
        _ -> error_not_found(conn)
      end
    else
      {:ok, nil}
    end
  end

  defp get_membership_role(nil, _site), do: nil
  defp get_membership_role(user, site), do: Plausible.Sites.role(user.id, site)

  defp error_not_found(conn) do
    case get_format(conn) do
      "json" ->
        conn
        |> PlausibleWeb.Api.Helpers.not_found(
          "Site does not exist or user does not have sufficient access."
        )
        |> halt()

      _ ->
        conn
        |> PlausibleWeb.ControllerHelpers.render_error(404)
        |> halt()
    end
  end
end
