defmodule PlausibleWeb.CustomerSupport.Team.Components.SSO do
  @moduledoc """
  Team SSO component - handles SSO integration management
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live
  alias Plausible.Auth.SSO

  def update(%{team: team}, socket) do
    sso_integration = get_sso_integration(team)
    {:ok, assign(socket, team: team, sso_integration: sso_integration)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-4 mb-4 text-gray-900 dark:text-gray-400">
      <div :if={@sso_integration}>
        <div class="flex gap-x-8 mb-4 justify-between items-start">
          <p>
            Configured?: <code>{SSO.Integration.configured?(@sso_integration)}</code>
            <br /> IDP Signin URL:
            <code>
              {@sso_integration.config.idp_signin_url}
            </code>
            <br />IDP Entity ID: <code>{@sso_integration.config.idp_entity_id}</code>
          </p>
          <div class="ml-auto">
            <.button
              data-confirm="Are you sure you want to remove this SSO team integration, including all its domains and users?"
              id="remove-sso-integration"
              phx-click="remove-sso-integration"
              phx-target={@myself}
              theme="danger"
            >
              Remove Integration
            </.button>
          </div>
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
                class="text-sm text-red-600"
                data-confirm={"Are you sure you want to remove domain '#{sso_domain.domain}'? All SSO users will be deprovisioned and logged out."}
              />
            </.td>
          </:tbody>
        </.table>
      </div>
      <div :if={!@sso_integration} class="text-center py-8 text-gray-500">
        <p>No SSO integration configured for this team.</p>
      </div>
    </div>
    """
  end

  def handle_event("remove-sso-integration", _, socket) do
    :ok = SSO.remove_integration(socket.assigns.sso_integration, force_deprovision?: true)

    socket =
      socket
      |> assign(sso_integration: nil)
      |> push_navigate(
        to: Routes.customer_support_team_path(socket, :show, socket.assigns.team.id)
      )

    success("SSO integration removed")

    {:noreply, socket}
  end

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
