defmodule PlausibleWeb.Live.GoalSettings.List do
  @moduledoc """
  Phoenix LiveComponent module that renders a list of goals
  """
  use Phoenix.LiveComponent
  use Phoenix.HTML

  use Plausible.Funnel
  alias Phoenix.LiveView.JS

  attr(:goals, :list, required: true)
  attr(:domain, :string, required: true)
  attr(:filter_text, :string)

  def render(assigns) do
    ~H"""
    <div>
      <div class="border-t border-gray-200 pt-4 sm:flex sm:items-center sm:justify-between">
        <form id="filter-form" phx-change="filter">
          <div class="text-gray-800 text-sm inline-flex items-center">
            <Heroicons.magnifying_glass
              class="feather mr-1 dark:text-gray-300"
              phx-click={JS.focus(to: "#filter-text")}
            />
            <input
              type="text"
              name="filter-text"
              id="filter-text"
              class={[
                "border-none rounded-md px-1 py-2 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm dark:text-gray-300 dark:bg-gray-800",
                String.trim(@filter_text) != "" &&
                  "bg-gray-100 focus:bg-white dark:bg-gray-850 dark:focus:bg-gray-900"
              ]}
              placeholder="Search Goals"
              value={@filter_text}
            />
            <Heroicons.backspace
              :if={String.trim(@filter_text) != ""}
              class="feather ml-2 cursor-pointer hover:text-red-500 dark:text-gray-300 dark:hover:text-red-500"
              phx-click="reset-filter-text"
              id="reset-filter"
            />
          </div>
        </form>
        <div class="mt-3 flex sm:ml-4 sm:mt-0">
          <button
            type="button"
            phx-click="add-goal"
            class="ml-3 inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            + Add Goal
          </button>
        </div>
      </div>
      <%= if Enum.count(@goals) > 0 do %>
        <div class="mt-12">
          <%= for goal <- @goals do %>
            <div class="border-b border-gray-300 dark:border-gray-500 py-3 flex justify-between">
              <span class="text-sm font-medium text-gray-900 dark:text-gray-100 w-3/4">
                <div class="flex">
                  <span class="truncate">
                    <%= goal %>
                    <br />
                    <span class="text-sm text-gray-400 block mt-1 font-normal">
                      <span :if={goal.page_path}>Pageview</span>
                      <span :if={goal.event_name && !goal.currency}>Custom Event</span>
                      <span :if={goal.currency}>
                        Revenue Goal: <%= goal.currency %>
                      </span>
                      <span :if={not Enum.empty?(goal.funnels)}> - belongs to funnel(s)</span>
                    </span>
                  </span>
                </div>
              </span>
              <button
                id={"delete-goal-#{goal.id}"}
                phx-click="delete-goal"
                phx-value-goal-id={goal.id}
                class="text-sm text-red-600"
                data-confirm={delete_confirmation_text(goal)}
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
            No goals found for this site. Please refine or
            <a
              class="text-indigo-500 cursor-pointer underline"
              phx-click="reset-filter-text"
              id="reset-filter-hint"
            >
              reset your search.
            </a>
          </span>
          <span :if={String.trim(@filter_text) == "" && Enum.empty?(@goals)}>
            No goals configured for this site.
          </span>
        </p>
      <% end %>
    </div>
    """
  end

  defp delete_confirmation_text(goal) do
    if Enum.empty?(goal.funnels) do
      """
      Are you sure you want to remove the following goal:

      #{goal}

      This will just affect the UI, all of your analytics data will stay intact.
      """
    else
      """
      The goal:

      #{goal}

      is part of some funnel(s). If you are going to delete it, the associated funnels will be either reduced or deleted completely. Are you sure you want to remove the goal?
      """
    end
  end
end
