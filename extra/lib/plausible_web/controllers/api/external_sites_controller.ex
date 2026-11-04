defmodule PlausibleWeb.Api.ExternalSitesController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler

  import Plausible.Pagination

  alias Plausible.Sites
  alias Plausible.Goal
  alias Plausible.Goals
  alias Plausible.Props
  alias Plausible.Teams
  alias PlausibleWeb.Api.Helpers, as: H

  @pagination_opts [cursor_fields: [{:id, :desc}], limit: 100, maximum_limit: 1000]

  # capability:begin
  # id: list_sites@sites_api
  # action: list_sites
  # transport: sites_api
  # entry: GET /api/v1/sites (router.ex scope "/api/v1/sites", assigns api_scope "sites:read:*", pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.index/2
  # credential: [api_key_team, api_key_legacy]
  # resource: team
  # current_scope: sites:read:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (implicit for every key)
  # current_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # current_role_enforced_by: none (membership only; query filter Sites.for_user_query)
  # current_feature_gate: [Plausible.Billing.Feature.StatsAPI, locked_check]
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: Team comes from the key, else ?team_id; legacy key without team_id gets no lock or feature check and lists sites across all teams including guest sites; with a team, guest sites are excluded (tm.role != :guest)
  # capability:end
  def index(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team || Teams.get(params["team_id"])

    page =
      user
      |> Sites.for_user_query(team)
      |> paginate(params, @pagination_opts)

    json(conn, %{
      sites: page.entries |> Enum.map(&get_site_response_for_index/1),
      meta: pagination_meta(page.metadata)
    })
  end

  # capability:begin
  # id: list_guests@sites_api
  # action: list_guests
  # transport: sites_api
  # entry: GET /api/v1/sites/guests (router.ex scope "/api/v1/sites", assigns api_scope "sites:read:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.guests_index/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:read:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (implicit for every key)
  # current_roles: [owner, admin, editor, viewer, guest_viewer, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor, :viewer]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.StatsAPI, locked_check]
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Returns guest emails; viewers and guest viewers can list them here, but the UI people page (SiteController.settings_people) requires editor or above, so proposed follows the UI; sites:read routes are gated on the StatsAPI feature, not SitesAPI
  # capability:end
  def guests_index(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor, :viewer]) do
      opts = [cursor_fields: [sort_index: :asc], limit: 100, maximum_limit: 1000]
      page = site |> Sites.list_guests_query() |> paginate(params, opts)

      json(conn, %{
        guests:
          Enum.map(page.entries, fn entry ->
            Map.take(entry, [:email, :role, :status])
          end),
        meta: pagination_meta(page.metadata)
      })
    else
      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to list goals")

      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  # capability:begin
  # id: list_teams@sites_api
  # action: list_teams
  # transport: sites_api
  # entry: GET /api/v1/sites/teams (router.ex scope "/api/v1/sites", assigns api_scope "sites:read:*", pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.teams_index/2
  # credential: [api_key_team, api_key_legacy]
  # resource: account
  # current_scope: sites:read:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (implicit for every key)
  # current_roles: [owner, admin, editor, viewer, billing]
  # current_role_enforced_by: none (membership only; query filter Teams.Users.teams_query excludes guest memberships)
  # current_feature_gate: none
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, viewer, billing]
  # confidence: verified
  # notes: Team key: only its own team; legacy key: all teams; no team or site to check, so no lock or feature gate, although api_available is reported per team; open question whether this needs teams:read
  # capability:end
  def teams_index(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    page =
      user
      |> Teams.Users.teams_query(identifier: team && team.identifier, order_by: :id_desc)
      |> paginate(params, @pagination_opts)

    json(conn, %{
      teams:
        Enum.map(page.entries, fn team ->
          api_available? =
            Plausible.Billing.Feature.StatsAPI.check_availability(team) == :ok

          %{
            id: team.identifier,
            name: Teams.name(team),
            api_available: api_available?
          }
        end),
      meta: pagination_meta(page.metadata)
    })
  end

  # capability:begin
  # id: list_goals@sites_api
  # action: list_goals
  # transport: sites_api
  # entry: GET /api/v1/sites/goals (router.ex scope "/api/v1/sites", assigns api_scope "sites:read:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.goals_index/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:read:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (implicit for every key)
  # current_roles: [owner, admin, editor, viewer, guest_viewer, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor, :viewer]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.StatsAPI, locked_check]
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: sites:read routes are gated on the StatsAPI feature, not SitesAPI; billing excluded by find_site, but billing can read the same data in the dashboard and via MCP list_sites, so proposed adds billing; super admin passes the plug but find_site has no :super_admin, so gets 404
  # capability:end
  def goals_index(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor, :viewer]) do
      page =
        site
        |> Plausible.Goals.for_site_query()
        |> paginate(params, @pagination_opts)

      json(conn, %{
        goals:
          Enum.map(page.entries, fn goal ->
            %{
              id: goal.id,
              display_name: goal.display_name,
              goal_type: Goal.type(goal),
              event_name: goal.event_name,
              page_path: goal.page_path,
              custom_props: goal.custom_props
            }
          end),
        meta: pagination_meta(page.metadata)
      })
    else
      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to list goals")

      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  # capability:begin
  # id: create_site@sites_api
  # action: create_site
  # transport: sites_api
  # entry: POST /api/v1/sites (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.create_site/2
  # credential: [api_key_team, api_key_legacy]
  # resource: team
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner, admin, editor]
  # current_role_enforced_by: Sites.create -> Memberships.can_add_site? (team role in [owner, admin, editor])
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check]
  # proposed_scope: sites:provision
  # proposed_roles: [owner, admin, editor]
  # confidence: verified
  # notes: Team comes from the key, else ?team_id; legacy key without team_id: no lock or feature check in the plug and Sites.create falls back to the user's own team (multiple_teams error if ambiguous); site limit via Teams.Billing.ensure_can_add_new_site; can_add_site? also blocks an SSO owner of a team whose setup isn't complete; the new site would have to be appended to a non-NULL grant site_ids
  # capability:end
  def create_site(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team || Teams.get(params["team_id"])

    case Repo.transact(fn ->
           with {:ok, %{site: site}} <- Sites.create(user, params, team),
                {:ok, tracker_script_configuration} <-
                  get_or_create_config(site, params["tracker_script_configuration"] || %{}) do
             {:ok,
              struct(site,
                tracker_script_configuration: tracker_script_configuration
              )}
           else
             # Translates Multi error format to Repo.transact error format
             {:error, step_id, output, context} ->
               {:error, {step_id, output, context}}

             # already in Repo.transact error format
             {:error, reason} ->
               {:error, reason}
           end
         end) do
      {:ok, site} ->
        json(conn, get_site_response(site))

      {:error, {_, {:over_limit, limit}, _}} ->
        conn
        |> put_status(402)
        |> json(%{
          error:
            "Your account has reached the limit of #{limit} sites. To unlock more sites, please upgrade your subscription."
        })

      {:error, {_, :permission_denied, _}} ->
        conn
        |> put_status(403)
        |> json(%{
          error: "You can't add sites to the selected team."
        })

      {:error, {_, :multiple_teams, _}} ->
        conn
        |> put_status(400)
        |> json(%{
          error: "You must select a team with 'team_id' parameter."
        })

      {:error, {:tracker_script_configuration_invalid, %Ecto.Changeset{} = changeset}} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset, "tracker_script_configuration."))

      {:error, {_, %Ecto.Changeset{} = changeset, _}} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset))
    end
  end

  # capability:begin
  # id: get_site@sites_api
  # action: get_site
  # transport: sites_api
  # entry: GET /api/v1/sites/:site_id (router.ex scope "/api/v1/sites", assigns api_scope "sites:read:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.get_site/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:read:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (implicit for every key)
  # current_roles: [owner, admin, editor, viewer, guest_viewer, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor, :viewer]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.StatsAPI, locked_check]
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: sites:read routes are gated on the StatsAPI feature, not SitesAPI; billing excluded by find_site, but billing can read the same data in the dashboard and via MCP list_sites, so proposed adds billing; super admin passes the plug but find_site has no :super_admin, so gets 404; a GET can write: get_or_create_config creates a tracker script configuration
  # capability:end
  def get_site(conn, %{"site_id" => site_id}) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor, :viewer]),
         {:ok, tracker_script_configuration} <- get_or_create_config(site, %{}) do
      site = struct(site, tracker_script_configuration: tracker_script_configuration)

      json(conn, get_site_response(site))
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  # capability:begin
  # id: delete_site@sites_api
  # action: delete_site
  # transport: sites_api
  # entry: DELETE /api/v1/sites/:site_id (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.delete_site/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check]
  # proposed_scope: sites:provision
  # proposed_roles: [owner, admin]
  # confidence: verified
  # notes: Owner only here, but the UI (SiteController.delete_site) also lets admins delete; proposed follows the UI
  # capability:end
  def delete_site(conn, %{"site_id" => site_id}) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    case find_site(user, team, site_id, [:owner]) do
      {:ok, site} ->
        {:ok, _} = Plausible.Site.Removal.run(site)
        json(conn, %{"deleted" => true})

      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  # capability:begin
  # id: update_site@sites_api
  # action: update_site
  # transport: sites_api
  # entry: PUT /api/v1/sites/:site_id (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.update_site/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner, admin, editor, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check]
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Changes domain and/or tracker script configuration; the UI splits these into ChangeDomain (domain) and tracker settings LiveViews
  # capability:end
  def update_site(conn, %{"site_id" => site_id} = params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, params} <- validate_update_payload(params),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]),
         {:ok, site} <- do_update_site(site, params) do
      json(conn, get_site_response(site))
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:error, :no_changes} ->
        H.bad_request(
          conn,
          "Payload must contain at least one of the parameters 'domain', 'tracker_script_configuration'"
        )

      {:error, {:domain_change_invalid, %Ecto.Changeset{} = changeset}} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset))

      {:error, {:tracker_script_configuration_invalid, %Ecto.Changeset{} = changeset}} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset, "tracker_script_configuration."))
    end
  end

  defp validate_update_payload(params) do
    params = params |> Map.take(["domain", "tracker_script_configuration"]) |> Map.drop([nil])

    if map_size(params) == 0 do
      {:error, :no_changes}
    else
      {:ok, params}
    end
  end

  defp do_update_site(site, params) do
    Repo.transact(fn ->
      with {:ok, site} <-
             if(params["domain"],
               do: change_domain(site, params["domain"]),
               else: {:ok, site}
             ),
           {:ok, tracker_script_configuration} <-
             if(params["tracker_script_configuration"],
               do: update_config(site, params["tracker_script_configuration"]),
               else: get_or_create_config(site, %{})
             ) do
        {:ok, struct(site, tracker_script_configuration: tracker_script_configuration)}
      end
    end)
  end

  defp change_domain(site, domain) do
    case Plausible.Site.Domain.change(site, domain) do
      {:ok, site} ->
        {:ok, site}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, {:domain_change_invalid, changeset}}
    end
  end

  # capability:begin
  # id: invite_guest@sites_api
  # action: invite_guest
  # transport: sites_api
  # entry: PUT /api/v1/sites/guests (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.find_or_create_guest/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner, admin]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin]); InviteToSite -> Invitations.check_invitation_permissions (team member owner/admin)
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check]
  # proposed_scope: access:write
  # proposed_roles: [owner, admin]
  # confidence: verified
  # notes: Team member limit via check_team_member_limit; covered by sites:provision today, proposed access:write because it grants other people access
  # capability:end
  def find_or_create_guest(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, email} <- expect_param_key(params, "email"),
         {:ok, role} <- expect_param_key(params, "role", ["viewer", "editor"]),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin]) do
      existing = Repo.one(Sites.list_guests_query(site, email: email))

      if existing do
        json(conn, %{
          role: existing.role,
          email: existing.email,
          status: existing.status
        })
      else
        case Teams.Invitations.InviteToSite.invite(
               site,
               conn.assigns.current_user,
               email,
               role
             ) do
          {:ok, invitation} ->
            json(conn, %{
              role: invitation.role,
              email: invitation.team_invitation.email,
              status: "invited"
            })
        end
      end
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:missing, "role"} ->
        H.bad_request(
          conn,
          "Parameter `role` is required to create guest. Possible values: `viewer` or `editor`"
        )

      {:missing, param} ->
        H.bad_request(conn, "Parameter `#{param}` is required to create guest")
    end
  end

  # capability:begin
  # id: remove_guest@sites_api
  # action: remove_guest
  # transport: sites_api
  # entry: DELETE /api/v1/sites/guests/:email (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.delete_guest/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner, admin]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check]
  # proposed_scope: access:write
  # proposed_roles: [owner, admin]
  # confidence: verified
  # notes: Removes a pending invitation or an accepted guest; the UI uses two endpoints for this (InvitationController.remove_invitation and Site.MembershipController.remove_member_by_user); Memberships.remove is called without the acting user, so find_site is the only role check
  # capability:end
  def delete_guest(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, email} <- expect_param_key(params, "email"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin]) do
      existing = Repo.one(Sites.list_guests_query(site, email: email))

      case existing do
        %{status: "invited", id: id} ->
          with guest_invitation when not is_nil(guest_invitation) <-
                 Repo.get(Teams.GuestInvitation, id) do
            Teams.Invitations.remove_guest_invitation(guest_invitation)
          end

        %{status: "accepted", email: email} ->
          with %{} = user <- Repo.get_by(Plausible.Auth.User, email: email) do
            Teams.Memberships.remove(site, user)
          end

        _ ->
          :ignore
      end

      json(conn, %{"deleted" => true})
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:missing, param} ->
        H.bad_request(conn, "Parameter `#{param}` is required to delete a guest")
    end
  end

  # capability:begin
  # id: create_shared_link@sites_api
  # action: create_shared_link
  # transport: sites_api
  # entry: PUT /api/v1/sites/shared-links (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.find_or_create_shared_link/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner, admin, editor, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check, Plausible.Billing.Feature.SharedLinks]
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Find-or-create by name; SharedLinks feature checked in Sites.create_shared_link
  # capability:end
  def find_or_create_shared_link(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, link_name} <- expect_param_key(params, "name"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]) do
      shared_link = Repo.get_by(Plausible.Site.SharedLink, site_id: site.id, name: link_name)

      shared_link =
        case shared_link do
          nil -> Sites.create_shared_link(site, link_name)
          link -> {:ok, link}
        end

      case shared_link do
        {:ok, link} ->
          json(conn, %{
            name: link.name,
            url: Sites.shared_link_url(site, link)
          })

        {:error, %Ecto.Changeset{} = changeset} ->
          {msg, _} = changeset.errors[:name]
          H.bad_request(conn, msg)

        {:error, :upgrade_required} ->
          H.payment_required(conn, "Your current subscription plan does not include Shared Links")
      end
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to create a shared link")

      {:missing, "name"} ->
        H.bad_request(conn, "Parameter `name` is required to create a shared link")

      e ->
        H.bad_request(conn, "Something went wrong: #{inspect(e)}")
    end
  end

  # capability:begin
  # id: create_goal@sites_api
  # action: create_goal
  # transport: sites_api
  # entry: PUT /api/v1/sites/goals (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.find_or_create_goal/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner, admin, editor, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check, Plausible.Billing.Feature.RevenueGoals, Plausible.Billing.Feature.Props]
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Find-or-create; RevenueGoals/Props features checked in Goals for revenue goals and goals with custom props
  # capability:end
  def find_or_create_goal(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, _} <- expect_param_key(params, "goal_type"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]),
         {:ok, goal} <- Goals.find_or_create(site, params) do
      json(conn, goal)
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:missing, param} ->
        H.bad_request(conn, "Parameter `#{param}` is required to create a goal")

      {:error, %Ecto.Changeset{} = changeset} ->
        message = Enum.map_join(changeset.errors, ", ", &translate_error/1)

        H.bad_request(conn, message)

      {:error, :upgrade_required} ->
        H.payment_required(
          conn,
          "Your current subscription plan does not include Custom Properties"
        )

      e ->
        H.bad_request(conn, "Something went wrong: #{inspect(e)}")
    end
  end

  # capability:begin
  # id: delete_goal@sites_api
  # action: delete_goal
  # transport: sites_api
  # entry: DELETE /api/v1/sites/goals/:goal_id (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.delete_goal/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner, admin, editor, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check]
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # capability:end
  def delete_goal(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, goal_id} <- expect_param_key(params, "goal_id"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]),
         :ok <- Goals.delete(goal_id, site) do
      json(conn, %{"deleted" => true})
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:error, :not_found} ->
        H.not_found(conn, "Goal could not be found")

      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to delete a goal")

      {:missing, "goal_id"} ->
        H.bad_request(conn, "Parameter `goal_id` is required to delete a goal")

      e ->
        H.bad_request(conn, "Something went wrong: #{inspect(e)}")
    end
  end

  # capability:begin
  # id: list_custom_props@sites_api
  # action: list_custom_props
  # transport: sites_api
  # entry: GET /api/v1/sites/custom-props (router.ex scope "/api/v1/sites", assigns api_scope "sites:read:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.custom_props_index/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:read:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (implicit for every key)
  # current_roles: [owner, admin, editor, viewer, guest_viewer, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor, :viewer]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.StatsAPI, locked_check]
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: sites:read routes are gated on the StatsAPI feature, not SitesAPI; billing excluded by find_site, but billing can read the same data in the dashboard and via MCP list_sites, so proposed adds billing; super admin passes the plug but find_site has no :super_admin, so gets 404
  # capability:end
  def custom_props_index(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor, :viewer]) do
      properties =
        (site.allowed_event_props || [])
        |> Enum.sort()
        |> Enum.map(fn prop -> %{property: prop} end)

      json(conn, %{custom_properties: properties})
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to list custom properties")
    end
  end

  # capability:begin
  # id: add_custom_prop@sites_api
  # action: add_custom_prop
  # transport: sites_api
  # entry: PUT /api/v1/sites/custom-props (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.add_custom_prop/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner, admin, editor, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check, Plausible.Billing.Feature.Props]
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Props feature checked in Props.allow
  # capability:end
  def add_custom_prop(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, property} <- expect_param_key(params, "property"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]),
         {:ok, _} <- Props.allow(site, property) do
      json(conn, %{"created" => true})
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:missing, param} ->
        H.bad_request(conn, "Parameter `#{param}` is required to create a custom property")

      {:error, :upgrade_required} ->
        H.payment_required(
          conn,
          "Your current subscription plan does not include Custom Properties"
        )

      {:error, changeset} ->
        %{allowed_event_props: [error | _]} =
          Ecto.Changeset.traverse_errors(changeset, fn {_msg, opts} ->
            cond do
              opts[:type] == :list and opts[:validation] == :length ->
                "Can't add any more custom properties"

              opts[:type] == :string and opts[:validation] == :length ->
                "Parameter `property` is too long"

              true ->
                "Parameter `property` is invalid"
            end
          end)

        H.bad_request(conn, error)
    end
  end

  # capability:begin
  # id: delete_custom_prop@sites_api
  # action: delete_custom_prop
  # transport: sites_api
  # entry: DELETE /api/v1/sites/custom-props/*property (router.ex scope "/api/v1/sites", assigns api_scope "sites:provision:*", api_context :site, pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalSitesController.delete_custom_prop/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: sites:provision:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (prefix match on key scopes)
  # current_roles: [owner, admin, editor, guest_editor]
  # current_role_enforced_by: controller find_site -> Sites.get_for_user(roles: [:owner, :admin, :editor]) (coalesce(guest role, team role))
  # current_feature_gate: [Plausible.Billing.Feature.SitesAPI, locked_check]
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # capability:end
  def delete_custom_prop(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, property} <- expect_param_key(params, "property"),
         # Property name is extracted from route URL via wildcard,
         # which returns a list.
         property = Path.join(property),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]),
         {:ok, _} <- Props.disallow(site, property) do
      json(conn, %{"deleted" => true})
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:missing, param} ->
        H.bad_request(conn, "Parameter `#{param}` is required to delete a custom property")

      e ->
        H.bad_request(conn, "Something went wrong: #{inspect(e)}")
    end
  end

  defp pagination_meta(meta) do
    %{
      after: meta.after,
      before: meta.before,
      limit: meta.limit
    }
  end

  defp find_site(user, team, site_id, roles) do
    case Plausible.Sites.get_for_user(user, site_id, roles: roles) do
      nil ->
        {:error, :site_not_found}

      site ->
        site = Repo.preload(site, :team)

        if team && team.id != site.team_id do
          {:error, :site_not_found}
        else
          {:ok, site}
        end
    end
  end

  defp serialize_errors(changeset, field_prefix \\ "") do
    {field, {msg, _opts}} = List.first(changeset.errors)
    error_msg = field_prefix <> Atom.to_string(field) <> ": " <> msg
    %{"error" => error_msg}
  end

  defp expect_param_key(params, key, inclusion \\ [])

  defp expect_param_key(params, key, []) do
    case Map.fetch(params, key) do
      :error -> {:missing, key}
      res -> res
    end
  end

  defp expect_param_key(params, key, inclusion) do
    case expect_param_key(params, key, []) do
      {:ok, value} = ok ->
        if value in inclusion, do: ok, else: {:missing, key}

      _ ->
        {:missing, key}
    end
  end

  defp get_or_create_config(site, params) do
    case PlausibleWeb.Tracker.get_or_create_tracker_script_configuration(site, params) do
      {:ok, tracker_script_configuration} ->
        {:ok, tracker_script_configuration}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, {:tracker_script_configuration_invalid, changeset}}
    end
  end

  defp update_config(site, params) do
    case PlausibleWeb.Tracker.update_script_configuration(site, params, :installation) do
      {:ok, tracker_script_configuration} ->
        {:ok, tracker_script_configuration}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, {:tracker_script_configuration_invalid, changeset}}
    end
  end

  defp get_site_response_for_index(site) do
    site |> Map.take([:domain, :timezone])
  end

  defp get_site_response(site) do
    site
    |> Map.take([:domain, :timezone, :tracker_script_configuration])
    # remap to `custom_properties`
    |> Map.put(:custom_properties, site.allowed_event_props || [])
  end

  defp translate_error({field, {msg, opts}}) do
    Enum.reduce(opts, "#{field}: #{msg}", fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
