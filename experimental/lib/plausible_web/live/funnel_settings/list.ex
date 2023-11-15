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

  def render(assigns) do
    ~H"""
    <div>
      <div class="border-t border-gray-200 pt-4 sm:flex sm:items-center sm:justify-between">
        <form id="filter-form" phx-change="filter">
          <div class="text-gray-800 text-sm inline-flex items-center">
            <div class="relative rounded-md shadow-sm flex">
              <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                <Heroicons.magnifying_glass class="feather mr-1 dark:text-gray-300" />
              </div>
              <input
                type="text"
                name="filter-text"
                id="filter-text"
                class="pl-8 shadow-sm dark:bg-gray-900 dark:text-gray-300 focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800"
                placeholder="Search Funnels"
                value={@filter_text}
              />
            </div>

            <Heroicons.backspace
              :if={String.trim(@filter_text) != ""}
              class="feather ml-2 cursor-pointer hover:text-red-500 dark:text-gray-300 dark:hover:text-red-500"
              phx-click="reset-filter-text"
              id="reset-filter"
            />
          </div>
        </form>
        <div class="mt-4 flex sm:ml-4 sm:mt-0">
          <PlausibleWeb.Components.Generic.button phx-click="add-funnel">
            + Add Funnel
          </PlausibleWeb.Components.Generic.button>
        </div>
      </div>
      <%= if Enum.count(@funnels) > 0 do %>
        <div class="mt-4">
          <%= for funnel <- @funnels do %>
            <div class="border-b border-gray-300 dark:border-gray-500 py-3 flex justify-between">
              <span class="text-sm font-medium text-gray-900 dark:text-gray-100">
                <%= funnel.name %>
                <span class="text-sm text-gray-400 font-normal block mt-1">
                  <%= funnel.steps_count %>-step funnel
                </span>
              </span>
              <button
                id={"delete-funnel-#{funnel.id}"}
                phx-click="delete-funnel"
                phx-value-funnel-id={funnel.id}
                class="text-sm text-red-600"
                data-confirm={"Are you sure you want to remove funnel '#{funnel.name}'? This will just affect the UI, all of your analytics data will stay intact."}
              >
                <svg
                  class="feather feather-sm"
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <polyline points="3 6 5 6 21 6"></polyline>
                  <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2">
                  </path>
                  <line x1="10" y1="11" x2="10" y2="17"></line>
                  <line x1="14" y1="11" x2="14" y2="17"></line>
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      <% else %>
        <p class="text-sm text-gray-800 dark:text-gray-200 mt-12 mb-8 text-center">
          <span :if={String.trim(@filter_text) != ""}>
            No funnels found for this site. Please refine or
            <a
              class="text-indigo-500 cursor-pointer underline"
              phx-click="reset-filter-text"
              id="reset-filter-hint"
            >
              reset your search.
            </a>
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
