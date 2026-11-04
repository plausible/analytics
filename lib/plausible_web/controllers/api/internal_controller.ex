defmodule PlausibleWeb.Api.InternalController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  import Ecto.Query
  alias Plausible.{Sites, Auth}
  alias Plausible.Auth.User
  alias Plausible.Teams

  # capability:begin
  # id: list_sites@internal_api
  # action: list_sites
  # transport: internal_api
  # entry: GET /api/sites (router.ex scope "/api", pipe_through :api)
  # handler: PlausibleWeb.Api.InternalController.sites/2
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # current_role_enforced_by: none (membership only; query filter Teams.Sites.accessible_by)
  # current_feature_gate: none
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: Site switcher; same query as the /sites LiveView
  # capability:end
  def sites(conn, _params) do
    current_user = conn.assigns[:current_user]
    current_team = conn.assigns[:current_team]

    if current_user do
      sites = sites_for(current_user, current_team)

      json(conn, %{data: sites})
    else
      PlausibleWeb.Api.Helpers.unauthorized(
        conn,
        "You need to be logged in to request a list of sites"
      )
    end
  end

  @features %{
    "funnels" => Plausible.Billing.Feature.Funnels,
    "props" => Plausible.Billing.Feature.Props,
    "conversions" => Plausible.Billing.Feature.Goals
  }
  # capability:begin
  # id: disable_site_feature@internal_api
  # action: disable_site_feature
  # transport: internal_api
  # entry: PUT /api/:domain/disable-feature (router.ex scope "/api", pipe_through :api)
  # handler: PlausibleWeb.Api.InternalController.disable_feature/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, guest_editor, super_admin]
  # current_role_enforced_by: controller: Memberships.has_editor_access? or Auth.super_admin?
  # current_feature_gate: none
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Hides funnels, props or conversions on the dashboard; the error message says owner or admin, but editors and guest editors pass
  # capability:end
  def disable_feature(conn, %{"domain" => domain, "feature" => feature}) do
    with %User{id: user_id} = user <- conn.assigns[:current_user],
         site <- Sites.get_by_domain(domain),
         true <-
           Plausible.Teams.Memberships.has_editor_access?(site, user) ||
             Auth.super_admin?(user_id),
         {:ok, mod} <- Map.fetch(@features, feature),
         {:ok, _site} <- mod.toggle(site, user, override: false) do
      json(conn, "ok")
    else
      {:error, :upgrade_required} ->
        PlausibleWeb.Api.Helpers.payment_required(
          conn,
          "This feature is part of the Plausible Business plan. To get access to this feature, please upgrade your account"
        )

      :error ->
        PlausibleWeb.Api.Helpers.bad_request(
          conn,
          "The feature you tried to disable is not valid. Valid features are: #{@features |> Map.keys() |> Enum.join(", ")}"
        )

      _ ->
        PlausibleWeb.Api.Helpers.unauthorized(
          conn,
          "You need to be logged in as the owner or admin account of this site"
        )
    end
  end

  # capability:begin
  # id: complete_site_onboarding@internal_api
  # action: complete_site_onboarding
  # transport: internal_api
  # entry: PUT /api/:domain/complete-onboarding (router.ex scope "/api", pipe_through :api)
  # handler: PlausibleWeb.Api.InternalController.complete_onboarding/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, guest_editor]
  # current_role_enforced_by: controller: Memberships.has_editor_access?
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: UI flow state
  # capability:end
  def complete_onboarding(conn, %{"domain" => domain}) do
    with %User{} = user <- conn.assigns[:current_user],
         site <- Sites.get_by_domain(domain),
         true <- Teams.Memberships.has_editor_access?(site, user) do
      site
      |> Plausible.Site.put_onboarding_status_advance(:completed)
      |> Repo.update!()

      json(conn, "ok")
    else
      _ ->
        PlausibleWeb.Api.Helpers.unauthorized(
          conn,
          "You need to be logged in as the owner, admin, or editor of this site"
        )
    end
  end

  defp sites_for(user, team) do
    from(u in subquery(Teams.Sites.accessible_by(user, team)),
      inner_join: s in ^Plausible.Site.regular(),
      on: u.site_id == s.id,
      left_join: up in Plausible.Site.UserPreference,
      on: up.site_id == s.id and up.user_id == ^user.id,
      select: %{
        domain: s.domain,
        needs_verification: ^ee?() and s.onboarding_status == :new_site
      },
      order_by: [
        asc:
          fragment(
            "CASE WHEN ? IS NOT NULL THEN 'pinned_site' ELSE 'site' END",
            up.pinned_at
          ),
        desc: up.pinned_at,
        asc: s.domain
      ],
      limit: 9
    )
    |> Repo.all()
  end
end
