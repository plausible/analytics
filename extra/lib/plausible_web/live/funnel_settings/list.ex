defmodule PlausibleWeb.Live.FunnelSettings.List do
  @moduledoc """
  Phoenix LiveComponent module that renders a list of funnels with their names
  and the number of steps they have.

  Each funnel is displayed with a delete button, which triggers a confirmation
  message before deleting the funnel from the UI. If there are no funnels
  configured for the site, a message is displayed indicating so.
  """
  use PlausibleWeb, :live_component

  def render(assigns) do
    assigns = assign(assigns, :searching?, String.trim(assigns.filter_text) != "")

    ~H"""
    <div>
      <%= if @searching? or Enum.count(@funnels) > 0 do %>
        <.filter_bar filter_text={@filter_text} placeholder="Search Funnels">
          <.button id="add-funnel-button" phx-click="add-funnel" mt?={false}>
            Add funnel
          </.button>
        </.filter_bar>
      <% end %>

      <%= if Enum.count(@funnels) > 0 do %>
        <.table rows={@funnels}>
          <:tbody :let={funnel}>
            <.td truncate>
              <span class="font-medium">{funnel.name}</span>
            </.td>
            <.td hide_on_mobile>
              <span class="text-gray-500 dark:text-gray-400">
                {funnel.steps_count}-step funnel
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
        <.no_search_results :if={@searching?} />
        <.empty_state :if={not @searching?} />
      <% end %>
    </div>
    """
  end

  defp no_search_results(assigns) do
    ~H"""
    <p class="mt-12 mb-8 text-sm text-center">
      No funnels found for this site. Please refine or
      <.styled_link phx-click="reset-filter-text" id="reset-filter-hint">
        reset your search.
      </.styled_link>
    </p>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center pt-5 pb-6 max-w-md mx-auto">
      <h3 class="text-center text-base font-medium text-gray-900 dark:text-gray-100 leading-7">
        Create your first funnel
      </h3>
      <p class="text-center text-sm mt-1 text-gray-500 dark:text-gray-400 leading-5 text-pretty">
        Compose goals into funnels to track user flows and conversion rates.
        <.styled_link href="https://plausible.io/docs/funnel-analysis" target="_blank">
          Learn more
        </.styled_link>
      </p>
      <.button
        id="add-funnel-button"
        phx-click="add-funnel"
        class="mt-4"
      >
        Add funnel
      </.button>
    </div>
    """
  end
end
