defmodule PlausibleWeb.Plugs.AuthorizeSiteAccess do
  @moduledoc """
  Plug restricting access to site and shared link, when present.
  """

  use Plausible.Repo

  import Plug.Conn
  import Phoenix.Controller, only: [get_format: 1]

  @all_roles [:public, :viewer, :admin, :super_admin, :owner]

  def init([]), do: @all_roles

  def init(allowed_roles) do
    unknown_roles = allowed_roles -- @all_roles

    if unknown_roles != [] do
      raise ArgumentError, "Unknown allowed roles configured: #{inspect(unknown_roles)}"
    end

    allowed_roles
  end

  def call(conn, allowed_roles) do
    current_user = conn.assigns[:current_user]

    with {:ok, %{site: site, membership_role: membership_role}} <-
           get_site_stuff(conn, current_user),
         {:ok, shared_link} <- maybe_get_shared_link(conn, site) do
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

  defp get_site_stuff(conn, current_user) do
    domain = conn.path_params["domain"] || conn.path_params["website"]

    ecto_query =
      from(
        s in Plausible.Site,
        where: s.domain == ^domain,
        select: %{site: s}
      )

    ecto_query =
      if current_user do
        from(s in ecto_query,
          left_join: sm in Plausible.Site.Membership,
          on: sm.site_id == s.id and sm.user_id == ^current_user.id,
          select_merge: %{membership_role: sm.role}
        )
      else
        from(s in ecto_query,
          select_merge: %{membership_role: nil}
        )
      end

    case Repo.one(ecto_query) do
      %{site: _site} = result -> {:ok, result}
      _ -> error_not_found(conn)
    end
  end

  defp maybe_get_shared_link(conn, site) do
    slug = conn.path_params["slug"] || conn.params["auth"]
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
