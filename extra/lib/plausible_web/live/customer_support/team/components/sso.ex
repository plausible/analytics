defmodule PlausibleWeb.CustomerSupport.Team.Components.SSO do
  @moduledoc """
  Team SSO component - handles SSO integration management
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live
  alias Plausible.Auth.SSO

  # capability:begin
  # id: cs_get_team_sso@ui_session
  # action: cs_get_team_sso
  # transport: ui_session
  # entry: live /cs/teams/team/:id?tab=sso update
  # handler: PlausibleWeb.CustomerSupport.Team.Components.SSO.update/2
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: cs:read
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: SSO integration, domains and policy
  # capability:end
  def update(%{team: team}, socket) do
    sso_integration = get_sso_integration(team)
    {:ok, assign(socket, team: team, sso_integration: sso_integration)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div :if={@sso_integration}>
        <div class="mt-4 mb-4 text-gray-900 dark:text-gray-400">
          <.table rows={
            [
              {"configured?", SSO.Integration.configured?(@sso_integration)},
              {"IDP Sign-in URL", @sso_integration.config.idp_signin_url},
              {"IDP Entity ID", @sso_integration.config.idp_entity_id}
            ] ++ Enum.into(Map.from_struct(@team.policy), [])
          }>
            <:tbody :let={{k, v}}>
              <.td>{k}</.td>
              <.td>{v}</.td>
            </:tbody>
          </.table>
        </div>

        <.table rows={@sso_integration.sso_domains}>
          <:thead>
            <.th>Domain</.th>
            <.th>Status</.th>
            <.th></.th>
          </:thead>
          <:tbody :let={sso_domain}>
            <.td>
              {sso_domain.domain}
            </.td>
            <.td>
              {sso_domain.status}
              <span :if={sso_domain.verified_via}>
                (via {sso_domain.verified_via} at {Calendar.strftime(
                  sso_domain.last_verified_at,
                  "%b %-d, %Y"
                )})
              </span>
            </.td>
            <.td actions>
              <.delete_button
                id={"remove-sso-domain-#{sso_domain.identifier}"}
                phx-click="remove-sso-domain"
                phx-value-identifier={sso_domain.identifier}
                phx-target={@myself}
                data-confirm={"Are you sure you want to remove domain '#{sso_domain.domain}'? All SSO users will be deprovisioned and logged out."}
              />
            </.td>
          </:tbody>
        </.table>

        <div class="flex justify-end">
          <.button
            data-confirm="Are you sure you want to remove this SSO team integration, including all its domains and users?"
            id="remove-sso-integration"
            phx-click="remove-sso-integration"
            phx-target={@myself}
            theme="danger"
            class="mt-6"
          >
            Remove Integration
          </.button>
        </div>
      </div>
      <div :if={!@sso_integration} class="text-center py-8 text-gray-500">
        <p>No SSO integration configured for this team.</p>
      </div>
    </div>
    """
  end

  # capability:begin
  # id: cs_remove_sso_integration@ui_session
  # action: cs_remove_sso_integration
  # transport: ui_session
  # entry: live /cs/teams/team/:id?tab=sso handle_event "remove-sso-integration"
  # handler: PlausibleWeb.CustomerSupport.Team.Components.SSO.handle_event/3
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: cs:delete
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: force_deprovision?: true, so every SSO user of the team is deprovisioned
  # capability:end
  def handle_event("remove-sso-integration", _, socket) do
    :ok = SSO.remove_integration(socket.assigns.sso_integration, force_deprovision?: true)

    socket =
      socket
      |> assign(sso_integration: nil)
      |> push_navigate(to: ~p"/cs/teams/team/#{socket.assigns.team.id}")

    success("SSO integration removed")

    {:noreply, socket}
  end

  # capability:begin
  # id: cs_remove_sso_domain@ui_session
  # action: cs_remove_sso_domain
  # transport: ui_session
  # entry: live /cs/teams/team/:id?tab=sso handle_event "remove-sso-domain"
  # handler: PlausibleWeb.CustomerSupport.Team.Components.SSO.handle_event/3
  # credential: [session]
  # resource: team
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: cs:delete
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: force_deprovision?: true for users on that domain
  # capability:end
  def handle_event("remove-sso-domain", %{"identifier" => i}, socket) do
    domain = Enum.find(socket.assigns.sso_integration.sso_domains, &(&1.identifier == i))
    :ok = SSO.Domains.remove(domain, force_deprovision?: true)

    success("SSO domain removed")

    {:noreply, assign(socket, sso_integration: get_sso_integration(socket.assigns.team))}
  end

  defp get_sso_integration(team) do
    case SSO.get_integration_for(team) do
      {:error, :not_found} -> nil
      {:ok, integration} -> integration
    end
  end
end
