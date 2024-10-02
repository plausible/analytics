defmodule PlausibleWeb.Live.FunnelSettings.List do
  @moduledoc """
  Phoenix LiveComponent module that renders a list of funnels with their names
  and the number of steps they have.

  Each funnel is displayed with a delete button, which triggers a confirmation
  message before deleting the funnel from the UI. If there are no funnels
  configured for the site, a message is displayed indicating so.
  """
  use Phoenix.LiveComponent
  use Phoenix.HTML
  import PlausibleWeb.Components.Generic

  def render(assigns) do
    ~H"""
    <div>
      <.filter_bar filter_text={@filter_text} placeholder="Search Funnels">
        <.button id="add-funnel-button" phx-click="add-funnel" mt?={false}>
          Add Funnel
        </.button>
      </.filter_bar>

      <%= if Enum.count(@funnels) > 0 do %>
        <.table rows={@funnels}>
          <:tbody :let={funnel}>
            <.td truncate>
              <span class="font-medium"><%= funnel.name %></span>
            </.td>
            <.td hide_on_mobile>
              <span class="text-gray-500 dark:text-gray-400">
                <%= funnel.steps_count %>-step funnel
              </span>
            </.td>
            <.td actions>
              <.edit_button phx-click="edit-funnel" phx-value-funnel-id={funnel.id} />
              <.delete_button
                id={"delete-funnel-#{funnel.id}"}
                phx-click="delete-funnel"
                phx-value-funnel-id={funnel.id}
                class="text-sm text-red-600"
                data-confirm={"Are you sure you want to remove funnel '#{funnel.name}'? This will just affect the UI, all of your analytics data will stay intact."}
              />
            </.td>
          </:tbody>
        </.table>
      <% else %>
        <p class="mt-12 mb-8 text-sm text-center">
          <span :if={String.trim(@filter_text) != ""}>
            No funnels found for this site. Please refine or
            <.styled_link phx-click="reset-filter-text" id="reset-filter-hint">
              reset your search.
            </.styled_link>
          </span>
          <span :if={String.trim(@filter_text) == "" && Enum.empty?(@funnels)}>
            No funnels configured for this site.
          </span>
        </p>
      <% end %>
    </div>
    """
  end
end
