defmodule PlausibleWeb.Plugs.AuthorizeSiteAccess do
  @moduledoc """
  Plug restricting access to site and shared link, when present.

  In order to permit access to site regardless of role:

  ```elixir
  plug AuthorizeSiteAccess
  ```

  or

  ```elixir
  plug AuthorizeSiteAccess, :all_roles
  ```

  Permit access for a subset of roles only:

  ```elixir
  plug AuthorizeSiteAccess, [:admin, :owner, :super_admin]
  ```

  Permit access using a custom site param:

  ```elixir
  plug AuthorizeSiteAccess, {[:admin, :owner, :super_admin], "site_id"}
  ```

  or in case where any role is allowed:

  ```elixir
  plug AuthorizeSiteAccess, {:all_roles, "site_id"}
  ```
  """

  use Plausible.Repo

  import Plug.Conn
  import Phoenix.Controller, only: [get_format: 1]

  @all_roles [:public, :viewer, :admin, :editor, :super_admin, :owner]

  def init([]), do: {@all_roles, nil}

  def init(:all_roles), do: {@all_roles, nil}

  def init(allowed_roles) when is_list(allowed_roles) do
    init({allowed_roles, nil})
  end

  def init({:all_roles, site_param}) do
    init({@all_roles, site_param})
  end

  def init({allowed_roles, site_param}) when is_list(allowed_roles) do
    allowed_roles =
      if allowed_roles == [] do
        @all_roles
      else
        allowed_roles
      end

    unknown_roles = allowed_roles -- @all_roles

    if unknown_roles != [] do
      raise ArgumentError, "Unknown allowed roles configured: #{inspect(unknown_roles)}"
    end

    if !is_binary(site_param) && !is_nil(site_param) do
      raise ArgumentError, "Invalid site param configured: #{inspect(site_param)}"
    end

    {allowed_roles, site_param}
  end

  def call(conn, {allowed_roles, site_param}) do
    current_user = conn.assigns[:current_user]

    with {:ok, domain} <- get_domain(conn, site_param),
         {:ok, %{site: site, role: membership_role}} <-
           get_site_with_role(conn, current_user, domain),
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

        site =
          site
          |> Repo.preload([
            :owners,
            :completed_imports,
            team: [subscription: Plausible.Teams.last_subscription_query()]
          ])

        conn = merge_assigns(conn, site: site, site_role: role)

        if not is_nil(current_user) and role not in [:public, nil] do
          assign(conn, :site_team, site.team)
        else
          conn
        end
      else
        error_not_found(conn)
      end
    end
  end

  defp valid_path_fragment?(fragment), do: is_binary(fragment) and String.valid?(fragment)

  defp get_domain(conn, nil) do
    domain = conn.path_params["domain"]

    if valid_path_fragment?(domain) do
      {:ok, domain}
    else
      error_not_found(conn)
    end
  end

  defp get_domain(conn, site_param) do
    domain = conn.params[site_param]

    if valid_path_fragment?(domain) do
      {:ok, domain}
    else
      error_not_found(conn)
    end
  end

  defp get_site_with_role(conn, current_user, domain) do
    site = Repo.get_by(Plausible.Site, domain: domain)

    if site do
      site_role =
        case Plausible.Teams.Memberships.site_role(site, current_user) do
          {:ok, role} -> role
          _ -> nil
        end

      {:ok, %{site: site, role: site_role}}
    else
      error_not_found(conn)
    end
  end

  defp maybe_get_shared_link(conn, site) do
    slug = conn.path_params["slug"] || conn.params["auth"]

    if valid_path_fragment?(slug) do
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
