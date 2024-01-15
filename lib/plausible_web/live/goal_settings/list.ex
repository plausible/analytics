defmodule PlausibleWeb.Live.GoalSettings.List do
  @moduledoc """
  Phoenix LiveComponent module that renders a list of goals
  """
  use Phoenix.LiveComponent, global_prefixes: ~w(x-)
  use Phoenix.HTML

  alias PlausibleWeb.Live.Components.Modal

  attr(:goals, :list, required: true)
  attr(:domain, :string, required: true)
  attr(:filter_text, :string)

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
                placeholder="Search Goals"
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
          <PlausibleWeb.Components.Generic.button
            id="add-goal-button"
            x-data
            x-on:click={Modal.JS.open("goals-form-modal")}
          >
            + Add Goal
          </PlausibleWeb.Components.Generic.button>
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
                        Revenue Goal
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
                <Heroicons.trash class="feather feather-sm" />
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
