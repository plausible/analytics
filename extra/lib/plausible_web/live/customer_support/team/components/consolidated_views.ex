defmodule PlausibleWeb.CustomerSupport.Team.Components.ConsolidatedViews do
  @moduledoc """
  Lists ConsolidatedViews of a team and allows creating one if none exist. Current
  limitation is one consolidated view per team, which always includes all sites of
  this team.
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live
  alias Plausible.ConsolidatedView

  def update(%{team: team}, socket) do
    consolidated_views = ConsolidatedView.get(team) |> List.wrap()
    {:ok, assign(socket, team: team, consolidated_views: consolidated_views)}
  end

  def render(assigns) do
    ~H"""
    <div data-test-id="consolidated-views-tab-content" class="mt-2 mb-4">
      <%= if Enum.empty?(@consolidated_views) do %>
        <div class="mx-auto flex flex-col items-center">
          <p>This team does not have a consolidated view yet.</p>
          <.button class="mx-auto" phx-click="create-consolidated-view" phx-target={@myself}>
            Create one
          </.button>
        </div>
      <% else %>
        <.table rows={@consolidated_views}>
          <:thead>
            <.th>Domain</.th>
            <.th>Timezone</.th>
            <.th invisible>Dashboard</.th>
            <.th invisible>Settings</.th>
            <.th invisible>Delete</.th>
          </:thead>

          <:tbody :let={consolidated_view}>
            <.td>{consolidated_view.domain}</.td>
            <.td>{consolidated_view.timezone}</.td>
            <.td>
              <.styled_link
                new_tab={true}
                href={Routes.stats_path(PlausibleWeb.Endpoint, :stats, consolidated_view.domain, [])}
              >
                Dashboard
              </.styled_link>
            </.td>
            <.td>
              <.styled_link
                new_tab={true}
                href={
                  Routes.site_path(
                    PlausibleWeb.Endpoint,
                    :settings_general,
                    consolidated_view.domain,
                    []
                  )
                }
              >
                Settings
              </.styled_link>
            </.td>
            <.td>
              <.delete_button phx-click="delete-consolidated-view" phx-target={@myself} />
            </.td>
          </:tbody>
        </.table>
      <% end %>
    </div>
    """
  end

  def handle_event("create-consolidated-view", _, socket) do
    case ConsolidatedView.enable(socket.assigns.team) do
      {:ok, consolidated_view} ->
        success("Consolidated view created")
        {:noreply, assign(socket, consolidated_views: [consolidated_view])}

      {:error, _} ->
        failure("Could not create consolidated View")
        {:noreply, socket}
    end
  end

  def handle_event("delete-consolidated-view", _, socket) do
    ConsolidatedView.disable(socket.assigns.team)
    success("Deleted consolidated view")
    {:noreply, assign(socket, consolidated_views: [])}
  end
end
