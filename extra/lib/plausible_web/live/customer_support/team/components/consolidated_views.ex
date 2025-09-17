defmodule PlausibleWeb.CustomerSupport.Team.Components.ConsolidatedViews do
  @moduledoc """
  [Experimental - new feature]

  Lists ConsolidatedViews of a team and allows creating one if none exist. Current
  limitation is one consolidated view per team, which always includes all sites of
  this team.
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live

  def update(%{team: team}, socket) do
    cvs =
      case Plausible.ConsolidatedView.get_for_team(team) do
        nil -> []
        cv -> [cv]
      end

    {:ok, assign(socket, team: team, consolidated_views: cvs)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-2 mb-4">
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
              <.delete_button
                phx-click="delete-consolidated-view"
                phx-value-id={consolidated_view.id}
                phx-target={@myself}
              />
            </.td>
          </:tbody>
        </.table>
      <% end %>
    </div>
    """
  end

  def handle_event("create-consolidated-view", _, socket) do
    case Plausible.ConsolidatedView.create_for_team(socket.assigns.team) do
      {:ok, cv} ->
        success("Consolidated view created")
        {:noreply, assign(socket, consolidated_views: [cv])}

      {:error, _} ->
        failure("Could not create consolidated View")
        {:noreply, socket}
    end
  end

  def handle_event("delete-consolidated-view", %{"id" => id}, socket) do
    Plausible.Repo.get!(Plausible.Site, id) |> Plausible.Repo.delete()
    success("Deleted consolidated view")
    {:noreply, assign(socket, consolidated_views: [])}
  end
end
