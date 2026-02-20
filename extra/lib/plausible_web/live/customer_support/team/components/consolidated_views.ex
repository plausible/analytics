defmodule PlausibleWeb.CustomerSupport.Team.Components.ConsolidatedViews do
  @moduledoc """
  Lists ConsolidatedViews of a team and allows creating one if none exist. Current
  limitation is one consolidated view per team, which always includes all sites of
  this team.
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live
  alias Plausible.ConsolidatedView
  alias Plausible.Stats

  def update(%{team: team}, socket) do
    consolidated_view = ConsolidatedView.get(team)

    sparkline_intervals =
      with true <- connected?(socket),
           {:ok, sparkline} <- Stats.Sparkline.safe_overview_24h(consolidated_view) do
        sparkline.intervals
      else
        _ ->
          Stats.Sparkline.empty_24h_intervals()
      end

    {:ok,
     assign(socket,
       team: team,
       consolidated_views: List.wrap(consolidated_view),
       sparkline_intervals: sparkline_intervals
     )}
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
            <.th>Available?</.th>
            <.th invisible>Dashboard</.th>
            <.th invisible>24H</.th>
            <.th invisible>Delete</.th>
          </:thead>

          <:tbody :let={consolidated_view}>
            <.td>{consolidated_view.domain}</.td>
            <.td>{consolidated_view.timezone}</.td>
            <.td>{availability(@team)}</.td>
            <.td>
              <.styled_link
                new_tab={true}
                href={Routes.stats_path(PlausibleWeb.Endpoint, :stats, consolidated_view.domain, [])}
              >
                Dashboard
              </.styled_link>
            </.td>

            <.td>
              <span class="h-[24px] text-indigo-500">
                <PlausibleWeb.Live.Components.Visitors.chart
                  intervals={@sparkline_intervals}
                  height={20}
                />
              </span>
            </.td>
            <.td>
              <.delete_button
                phx-click="delete-consolidated-view"
                phx-target={@myself}
                data-confirm="Are you sure you want to delete this consolidated view? All existing consolidated view configuration will be lost. The view itself will be recreated whenever eligible subscription/trial accesses /sites for that team."
              />
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

      {:error, reason} ->
        failure("Could not create consolidated view. Reason: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_event("delete-consolidated-view", _, socket) do
    ConsolidatedView.disable(socket.assigns.team)
    success("Deleted consolidated view")
    {:noreply, assign(socket, consolidated_views: [])}
  end

  defp availability(team) do
    case Plausible.Billing.Feature.ConsolidatedView.check_availability(team) do
      :ok -> "Yes"
      {:error, :upgrade_required} -> "No - upgrade required"
    end
  end
end
