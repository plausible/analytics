defmodule PlausibleWeb.Plugs.AuthorizeSiteAccess do
  @moduledoc """
  Plug restricting access to site and shared link, when present.
  """

  use Plausible.Repo

  import Plug.Conn
  import Phoenix.Controller, only: [get_format: 1]

  @all_roles [:public, :viewer, :admin, :super_admin, :owner]

  def init([]), do: @all_roles

  def init(allowed_roles) when is_list(allowed_roles) do
    unknown_roles = allowed_roles -- @all_roles

    if unknown_roles != [] do
      raise ArgumentError, "Unknown allowed roles configured: #{inspect(unknown_roles)}"
    end

    allowed_roles
  end

  def init({allowed_roles, conn_params_domain_accessor})
      when is_list(allowed_roles) and is_binary(conn_params_domain_accessor) do
    {init(allowed_roles), conn_params_domain_accessor}
  end

  def call(conn, options) do
    current_user = conn.assigns[:current_user]

    {allowed_roles, conn_params_domain_accessor} =
      if is_tuple(options) do
        options
      else
        {options, nil}
      end

    with {:ok, %{site: site, role: membership_role}} <-
           get_site_with_role(conn, current_user, conn_params_domain_accessor),
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

  defp get_domain_from_conn(conn, nil) do
    conn.path_params["domain"] || conn.path_params["website"]
  end

  defp get_domain_from_conn(conn, conn_params_domain_accessor) do
    conn.params[conn_params_domain_accessor]
  end

  defp get_site_with_role(conn, current_user, conn_params_domain_accessor) do
    domain = get_domain_from_conn(conn, conn_params_domain_accessor)

    site_query =
      from(
        s in Plausible.Site,
        where: s.domain == ^domain,
        select: %{site: s}
      )

    full_query =
      if current_user do
        from(s in site_query,
          left_join: sm in Plausible.Site.Membership,
          on: sm.site_id == s.id and sm.user_id == ^current_user.id,
          select_merge: %{role: sm.role}
        )
      else
        from(s in site_query,
          select_merge: %{role: nil}
        )
      end

    case Repo.one(full_query) do
      %{site: _site} = result -> {:ok, result}
      _ -> error_not_found(conn)
    end
  end

  defp maybe_get_shared_link(conn, site) do
    slug = conn.path_params["slug"] || conn.params["auth"]

    if is_binary(slug) do
      if shared_link = Repo.get_by(Plausible.Site.SharedLink, slug: slug, site_id: site.id) do
        {:ok, shared_link}
      else
        error_not_found(conn)
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
