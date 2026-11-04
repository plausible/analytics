defmodule PlausibleWeb.SettingsController do
  use PlausibleWeb, :controller
  use Plausible
  use Plausible.Repo

  alias Plausible.Auth
  alias Plausible.Teams

  require Logger

  plug Plausible.Plugs.AuthorizeTeamAccess,
       [:owner, :admin]
       when action in [:update_team_name]

  plug Plausible.Plugs.AuthorizeTeamAccess,
       [:owner]
       when action in [
              :team_danger_zone,
              :delete_team,
              :enable_team_force_2fa,
              :disable_team_force_2fa
            ]

  plug Plausible.Plugs.RestrictUserType,
       [deny: :sso] when action in [:update_name, :update_email, :update_password]

  plug :require_mcp_feature_flag when action in [:connected_apps, :revoke_connected_app]

  def index(conn, _params) do
    redirect(conn, to: ~p"/settings/preferences")
  end

  def team_general(conn, _params) do
    render_team_general(conn)
  end

  # capability:begin
  # id: rename_team@ui_session
  # action: rename_team
  # transport: ui_session
  # entry: POST /settings/team/general/name (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.update_team_name/2
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin]
  # current_role_enforced_by: SettingsController plug AuthorizeTeamAccess [:owner, :admin]
  # current_feature_gate: none
  # proposed_scope: teams:write
  # proposed_roles: [owner, admin]
  # confidence: verified
  # notes: NEW SCOPE: teams:write, for team settings that are safe to delegate; no API or MCP equivalent
  # capability:end
  def update_team_name(conn, %{"team" => params}) do
    changeset = Teams.Team.name_changeset(conn.assigns.current_team, params)

    case Repo.update(changeset) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Team name changed")
        |> redirect(to: ~p"/settings/team/general#update-name")

      {:error, changeset} ->
        render_team_general(conn, team_name_changeset: changeset)
    end
  end

  defp render_team_general(conn, opts \\ []) do
    if Teams.setup?(conn.assigns.current_team) do
      name_changeset =
        Keyword.get(
          opts,
          :team_name_changeset,
          Teams.Team.name_changeset(conn.assigns.current_team)
        )

      render(conn, :team_general,
        team_name_changeset: name_changeset,
        layout: {PlausibleWeb.LayoutView, :settings},
        connect_live_socket: true
      )
    else
      conn
      |> redirect(to: ~p"/sites")
    end
  end

  # capability:begin
  # id: enable_team_force_2fa@ui_session
  # action: enable_team_force_2fa
  # transport: ui_session
  # entry: POST /settings/team/force_2fa/enable (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.enable_team_force_2fa/2
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner]
  # current_role_enforced_by: SettingsController plug AuthorizeTeamAccess [:owner]
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [owner]
  # confidence: verified
  # notes: Security policy, keep session only
  # capability:end
  def enable_team_force_2fa(conn, _params) do
    team = conn.assigns.current_team
    user = conn.assigns.current_user

    case Teams.enable_force_2fa(team, user) do
      {:ok, _} ->
        conn
        |> put_flash(:success, "2FA is now required for all team members.")
        |> redirect(to: ~p"/settings/team/general")

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to enforce 2FA for all team members.")
        |> redirect(to: ~p"/settings/team/general")
    end
  end

  # capability:begin
  # id: disable_team_force_2fa@ui_session
  # action: disable_team_force_2fa
  # transport: ui_session
  # entry: POST /settings/team/force_2fa/disable (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.disable_team_force_2fa/2
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner]
  # current_role_enforced_by: SettingsController plug AuthorizeTeamAccess [:owner]
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [owner]
  # confidence: verified
  # notes: Security policy, requires the password
  # capability:end
  def disable_team_force_2fa(conn, %{"password" => password}) do
    team = conn.assigns.current_team
    user = conn.assigns.current_user

    case Teams.disable_force_2fa(team, user, password) do
      {:ok, _} ->
        conn
        |> put_flash(:success, "2FA is no longer enforced for team members.")
        |> redirect(to: ~p"/settings/team/general")

      {:error, :invalid_password} ->
        conn
        |> put_flash(:error, "Incorrect password provided.")
        |> redirect(to: ~p"/settings/team/general")

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to disable enforcing 2FA for all team members.")
        |> redirect(to: ~p"/settings/team/general")
    end
  end

  # capability:begin
  # id: leave_team@ui_session
  # action: leave_team
  # transport: ui_session
  # entry: POST /settings/team/leave (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.leave_team/2
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, viewer, billing]
  # current_role_enforced_by: Teams.Memberships.Leave.leave (any member; last owner can't leave)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [owner, admin, editor, viewer, billing]
  # confidence: verified
  # capability:end
  def leave_team(conn, _params) do
    case Teams.Memberships.Leave.leave(conn.assigns.current_team, conn.assigns.current_user) do
      {:ok, _} ->
        conn
        |> put_flash(:success, "You have left \"#{Teams.name(conn.assigns.current_team)}\"")
        |> redirect(to: ~p"/sites?#{[__team: "none"]}")

      {:error, :only_one_owner} ->
        conn
        |> put_flash(:error, "You can't leave as you are the only Owner on the team")
        |> redirect(to: ~p"/settings/team/general")

      {:error, :membership_not_found} ->
        redirect(conn, to: ~p"/sites?#{[__team: "none"]}")
    end
  end

  def preferences(conn, _params) do
    render_preferences(conn)
  end

  # capability:begin
  # id: list_user_sessions@ui_session
  # action: list_user_sessions
  # transport: ui_session
  # entry: GET /settings/security (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.security/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: Own sessions, rendered with the email and password forms
  # capability:end
  def security(conn, _params) do
    render_security(conn)
  end

  # capability:begin
  # id: list_guest_sites@ui_session
  # action: list_guest_sites
  # transport: ui_session
  # entry: GET /settings/guest-sites (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.guest_sites/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: Own guest memberships
  # capability:end
  def guest_sites(conn, _params) do
    case Teams.Memberships.guest_memberships(conn.assigns.current_user) do
      [] ->
        redirect(conn, to: ~p"/settings/preferences")

      guest_memberships ->
        render(conn, :guest_sites,
          guest_memberships: guest_memberships,
          layout: {PlausibleWeb.LayoutView, :settings}
        )
    end
  end

  # capability:begin
  # id: leave_guest_site@ui_session
  # action: leave_guest_site
  # transport: ui_session
  # entry: DELETE /settings/guest-sites/:site_id (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.leave_guest_site/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [guest_viewer, guest_editor]
  # current_role_enforced_by: Teams.Memberships.remove(site_id, current_user) (own guest membership only)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [guest_viewer, guest_editor]
  # confidence: verified
  # capability:end
  def leave_guest_site(conn, %{"site_id" => site_id}) do
    user = conn.assigns.current_user

    conn =
      case Teams.Memberships.remove(site_id, user, send_email?: false) do
        {:ok, guest_membership} ->
          put_flash(conn, :success, "You have left #{guest_membership.site.domain}")

        {:error, :no_guest} ->
          put_flash(conn, :error, "You're no longer a guest of this site")
      end

    redirect(conn, to: ~p"/settings/guest-sites")
  end

  def redirect_invoices(conn, _params) do
    redirect(conn, to: ~p"/settings/billing/subscription")
  end

  # capability:begin
  # id: list_api_keys@ui_session
  # action: list_api_keys
  # transport: ui_session
  # entry: GET /settings/api-keys (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.api_keys/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: Own keys, scoped to the current team (Auth.list_api_keys)
  # capability:end
  def api_keys(conn, _params) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns[:current_team]

    api_keys = Auth.list_api_keys(current_user, current_team)

    render(conn, :api_keys, layout: {PlausibleWeb.LayoutView, :settings}, api_keys: api_keys)
  end

  def new_api_key(conn, _params) do
    current_team = conn.assigns[:current_team]

    sites_api_enabled? =
      Plausible.Billing.Feature.SitesAPI.check_availability(current_team) == :ok

    changeset = Auth.ApiKey.changeset(%Auth.ApiKey{type: "stats_api"}, current_team, %{})

    render(conn, "new_api_key.html", changeset: changeset, sites_api_enabled?: sites_api_enabled?)
  end

  # capability:begin
  # id: create_api_key@ui_session
  # action: create_api_key
  # transport: ui_session
  # entry: POST /settings/api-keys (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.create_api_key/2
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, viewer, billing]
  # current_role_enforced_by: none (membership only; current team from the session)
  # current_feature_gate: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.SitesAPI]
  # proposed_scope: none
  # proposed_roles: [owner, admin, editor, viewer, billing]
  # confidence: verified
  # notes: No role check: any member, including viewer and billing, can create a Stats or Sites API key for the team; roles only matter when the key is used, and the Stats API checks none
  # capability:end
  def create_api_key(conn, %{"api_key" => %{"name" => name, "key" => key, "type" => type}}) do
    current_user = conn.assigns.current_user
    current_team = conn.assigns.current_team

    sites_api_enabled? =
      Plausible.Billing.Feature.SitesAPI.check_availability(current_team) == :ok

    api_key_fn =
      if type == "sites_api" do
        &Auth.create_sites_api_key/4
      else
        &Auth.create_stats_api_key/4
      end

    case api_key_fn.(current_user, current_team, name, key) do
      {:ok, _api_key} ->
        conn
        |> put_flash(:success, "API key created successfully")
        |> redirect(to: ~p"/settings/api-keys#api-keys")

      {:error, :upgrade_required} ->
        conn
        |> put_flash(:error, "Your current subscription plan does not include Sites API access")
        |> redirect(to: ~p"/settings/api-keys/new")

      {:error, changeset} ->
        render(conn, "new_api_key.html",
          changeset: changeset,
          sites_api_enabled?: sites_api_enabled?
        )
    end
  end

  # capability:begin
  # id: delete_api_key@ui_session
  # action: delete_api_key
  # transport: ui_session
  # entry: DELETE /settings/api-keys/:id (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.delete_api_key/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: Own keys only (Auth.delete_api_key scopes by user)
  # capability:end
  def delete_api_key(conn, %{"id" => id}) do
    case Auth.delete_api_key(conn.assigns.current_user, id) do
      :ok ->
        conn
        |> put_flash(:success, "API key revoked successfully")
        |> redirect(to: ~p"/settings/api-keys#api-keys")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Could not find API Key to delete")
        |> redirect(to: ~p"/settings/api-keys#api-keys")
    end
  end

  # capability:begin
  # id: list_connected_apps@ui_session
  # action: list_connected_apps
  # transport: ui_session
  # entry: GET /settings/connected-apps (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.connected_apps/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: Own OAuth grants; behind the :mcp feature flag
  # capability:end
  def connected_apps(conn, _params) do
    grants = Plausible.OAuth.list_grants(conn.assigns.current_user)

    render(conn, :connected_apps, layout: {PlausibleWeb.LayoutView, :settings}, grants: grants)
  end

  # capability:begin
  # id: revoke_connected_app@ui_session
  # action: revoke_connected_app
  # transport: ui_session
  # entry: DELETE /settings/connected-apps/:id (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.revoke_connected_app/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: Revokes an OAuth grant; own grants only; behind the :mcp feature flag
  # capability:end
  def revoke_connected_app(conn, %{"id" => id}) do
    case Plausible.OAuth.revoke_user_grant(conn.assigns.current_user, id) do
      :ok ->
        conn
        |> put_flash(:success, "Access revoked successfully")
        |> redirect(to: ~p"/settings/connected-apps#connected-apps")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Could not find connected app to revoke")
        |> redirect(to: ~p"/settings/connected-apps#connected-apps")
    end
  end

  # remove on rollout
  defp require_mcp_feature_flag(conn, _opts) do
    if FunWithFlags.enabled?(:mcp, for: conn.assigns.current_user) do
      conn
    else
      conn
      |> render_error(404)
      |> halt()
    end
  end

  def danger_zone(conn, _params) do
    solely_owned_teams =
      conn.assigns.current_user
      |> Teams.Users.owned_teams()
      |> Enum.filter(& &1.setup_complete)
      |> Enum.reject(fn team ->
        Teams.Memberships.owners_count(team) > 1
      end)

    render(conn, :danger_zone,
      solely_owned_teams: solely_owned_teams,
      layout: {PlausibleWeb.LayoutView, :settings}
    )
  end

  def team_danger_zone(conn, _params) do
    render(conn, :team_danger_zone, layout: {PlausibleWeb.LayoutView, :settings})
  end

  # capability:begin
  # id: delete_team@ui_session
  # action: delete_team
  # transport: ui_session
  # entry: DELETE /settings/team/delete (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.delete_team/2
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner]
  # current_role_enforced_by: SettingsController plug AuthorizeTeamAccess [:owner]
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [owner]
  # confidence: verified
  # capability:end
  def delete_team(conn, _params) do
    team = conn.assigns.current_team

    case Plausible.Teams.delete(team) do
      {:ok, :deleted} ->
        conn
        |> put_flash(:success, ~s|Team "#{Plausible.Teams.name(team)}" deleted|)
        |> redirect(to: ~p"/sites?#{[__team: "none"]}")

      {:error, :active_subscription} ->
        conn
        |> put_flash(
          :error,
          "Team has an active subscription. You must cancel it first."
        )
        |> redirect(to: ~p"/settings/team/delete")
    end
  end

  # Preferences actions

  # capability:begin
  # id: update_name@ui_session
  # action: update_name
  # transport: ui_session
  # entry: POST /settings/preferences/name (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.update_name/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: SSO users denied (RestrictUserType)
  # capability:end
  def update_name(conn, %{"user" => params}) do
    changeset = Auth.User.name_changeset(conn.assigns.current_user, params)

    case Repo.update(changeset) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Name changed")
        |> redirect(to: ~p"/settings/preferences#update-name")

      {:error, changeset} ->
        render_preferences(conn, name_changeset: changeset)
    end
  end

  # capability:begin
  # id: update_theme@ui_session
  # action: update_theme
  # transport: ui_session
  # entry: POST /settings/preferences/theme (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.update_theme/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # capability:end
  def update_theme(conn, %{"user" => params}) do
    changeset = Auth.User.theme_changeset(conn.assigns.current_user, params)

    case Repo.update(changeset) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Theme changed")
        |> redirect(to: ~p"/settings/preferences#update-theme")

      {:error, changeset} ->
        render_preferences(conn, theme_changeset: changeset)
    end
  end

  defp render_preferences(conn, opts \\ []) do
    name_changeset =
      Keyword.get(opts, :name_changeset, Auth.User.name_changeset(conn.assigns.current_user))

    theme_changeset =
      Keyword.get(opts, :theme_changeset, Auth.User.theme_changeset(conn.assigns.current_user))

    render(conn, :preferences,
      name_changeset: name_changeset,
      theme_changeset: theme_changeset,
      layout: {PlausibleWeb.LayoutView, :settings}
    )
  end

  # Security actions

  # capability:begin
  # id: update_email@ui_session
  # action: update_email
  # transport: ui_session
  # entry: POST /settings/security/email (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.update_email/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: SSO users denied (RestrictUserType)
  # capability:end
  def update_email(conn, %{"user" => params}) do
    user = conn.assigns.current_user

    with :ok <- Auth.rate_limit(:email_change_user, user),
         changes = Auth.User.email_changeset(user, params),
         {:ok, user} <- Repo.update(changes) do
      if user.email_verified do
        handle_email_updated(conn)
      else
        Auth.EmailVerification.issue_code(user)
        redirect(conn, to: ~p"/activate")
      end
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render_security(conn, email_changeset: changeset)

      {:error, {:rate_limit, _}} ->
        changeset =
          user
          |> Auth.User.email_changeset(params)
          |> Ecto.Changeset.add_error(:email, "too many requests, try again in an hour")
          |> Map.put(:action, :validate)

        render_security(conn, email_changeset: changeset)
    end
  end

  # capability:begin
  # id: cancel_update_email@ui_session
  # action: cancel_update_email
  # transport: ui_session
  # entry: POST /settings/security/email/cancel (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.cancel_update_email/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # capability:end
  def cancel_update_email(conn, _params) do
    changeset = Auth.User.cancel_email_changeset(conn.assigns.current_user)

    case Repo.update(changeset) do
      {:ok, user} ->
        conn
        |> put_flash(:success, "Email changed back to #{user.email}")
        |> redirect(to: ~p"/settings/security#update-email")

      {:error, _} ->
        conn
        |> put_flash(
          :error,
          "Could not cancel email update because previous email has already been taken"
        )
        |> redirect(to: ~p"/activate")
    end
  end

  # capability:begin
  # id: update_password@ui_session
  # action: update_password
  # transport: ui_session
  # entry: POST /settings/security/password (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.update_password/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: SSO users denied (RestrictUserType)
  # capability:end
  def update_password(conn, %{"user" => params}) do
    user = conn.assigns.current_user
    user_session = conn.assigns.current_user_session

    with :ok <- Auth.rate_limit(:password_change_user, user),
         {:ok, user} <- do_update_password(user, params) do
      Auth.UserSessions.revoke_all(user, except: user_session)

      conn
      |> put_flash(:success, "Your password is now changed")
      |> redirect(to: ~p"/settings/security#update-password")
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render_security(conn, password_changeset: changeset)

      {:error, {:rate_limit, _}} ->
        changeset =
          user
          |> Auth.User.password_changeset(params)
          |> Ecto.Changeset.add_error(:password, "too many attempts, try again in 20 minutes")
          |> Map.put(:action, :validate)

        render_security(conn, password_changeset: changeset)
    end
  end

  defp render_security(conn, opts \\ []) do
    user_sessions = Auth.UserSessions.list_for_user(conn.assigns.current_user)

    email_changeset =
      Keyword.get(
        opts,
        :email_changeset,
        Auth.User.email_changeset(conn.assigns.current_user, %{email: ""})
      )

    password_changeset =
      Keyword.get(
        opts,
        :password_changeset,
        Auth.User.password_changeset(conn.assigns.current_user)
      )

    render(conn, :security,
      totp_enabled?: Auth.TOTP.enabled?(conn.assigns.current_user),
      user_sessions: user_sessions,
      email_changeset: email_changeset,
      password_changeset: password_changeset,
      layout: {PlausibleWeb.LayoutView, :settings},
      connect_live_socket: true
    )
  end

  # capability:begin
  # id: revoke_user_session@ui_session
  # action: revoke_user_session
  # transport: ui_session
  # entry: DELETE /settings/security/user-sessions/:id (router.ex scope "/settings", pipe_through [:browser, :csrf, RequireAccountPlug, CurrentPath])
  # handler: PlausibleWeb.SettingsController.delete_session/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: n/a (own account; RequireAccountPlug)
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # capability:end
  def delete_session(conn, %{"id" => session_id}) do
    current_user = conn.assigns.current_user

    :ok = Auth.UserSessions.revoke_by_id(current_user, session_id)

    conn
    |> put_flash(:success, "Session logged out successfully")
    |> redirect(to: ~p"/settings/security#user-sessions")
  end

  defp do_update_password(user, params) do
    changes = Auth.User.password_changeset(user, params)

    Repo.transaction(fn ->
      with {:ok, user} <- Repo.update(changes),
           {:ok, user} <- validate_2fa_code(user, params["two_factor_code"]) do
        user
      else
        {:error, :invalid_2fa} ->
          changes
          |> Ecto.Changeset.add_error(:password, "invalid 2FA code")
          |> Map.put(:action, :validate)
          |> Repo.rollback()

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp validate_2fa_code(user, code) do
    if Auth.TOTP.enabled?(user) do
      case Auth.TOTP.validate_code(user, code) do
        {:ok, user} -> {:ok, user}
        {:error, :not_enabled} -> {:ok, user}
        {:error, _} -> {:error, :invalid_2fa}
      end
    else
      {:ok, user}
    end
  end

  defp handle_email_updated(conn) do
    conn
    |> put_flash(:success, "Email updated")
    |> redirect(to: ~p"/settings/security#update-email")
  end
end
