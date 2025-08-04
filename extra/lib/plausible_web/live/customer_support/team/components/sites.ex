defmodule PlausibleWeb.CustomerSupport.Team.Components.Sites do
  @moduledoc """
  Team sites component - handles team sites listing
  """
  use PlausibleWeb, :live_component
  alias Plausible.Teams
  alias PlausibleWeb.Router.Helpers, as: Routes
  import PlausibleWeb.Components.Generic

  def update(%{team: team}, socket) do
    sites = Teams.owned_sites(team, 100)
    sites_count = Teams.owned_sites_count(team)

    {:ok, assign(socket, team: team, sites: sites, sites_count: sites_count)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-2">
      <.notice :if={@sites_count > 100} class="mt-4 mb-4">
        This team owns more than 100 sites. Displaying first 100 below.
      </.notice>
      <.table rows={@sites}>
        <:thead>
          <.th>Domain</.th>
          <.th>Previous Domain</.th>
          <.th>Timezone</.th>
          <.th invisible>Settings</.th>
          <.th invisible>Dashboard</.th>
        </:thead>
        <:tbody :let={site}>
          <.td>
            <div class="flex items-center">
              <img
                src="/favicon/sources/{site.domain}"
                onerror="this.onerror=null; this.src='/favicon/sources/placeholder';"
                class="w-4 h-4 flex-shrink-0 mt-px mr-2"
              />
              <.styled_link
                patch={"/cs/sites/site/#{site.id}"}
                class="cursor-pointer flex block items-center"
              >
                {site.domain}
              </.styled_link>
            </div>
          </.td>
          <.td>{site.domain_changed_from || "--"}</.td>
          <.td>{site.timezone}</.td>
          <.td>
            <.styled_link
              new_tab={true}
              href={Routes.stats_path(PlausibleWeb.Endpoint, :stats, site.domain, [])}
            >
              Dashboard
            </.styled_link>
          </.td>
          <.td>
            <.styled_link
              new_tab={true}
              href={Routes.site_path(PlausibleWeb.Endpoint, :settings_general, site.domain, [])}
            >
              Settings
            </.styled_link>
          </.td>
        </:tbody>
      </.table>
    </div>
    """
  end
end
