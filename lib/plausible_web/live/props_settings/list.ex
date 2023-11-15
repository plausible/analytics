defmodule PlausibleWeb.Live.PropsSettings.List do
  @moduledoc """
  Phoenix LiveComponent module that renders a list of custom properties
  """
  use Phoenix.LiveComponent
  use Phoenix.HTML

  attr(:props, :list, required: true)
  attr(:domain, :string, required: true)
  attr(:filter_text, :string)

  def render(assigns) do
    ~H"""
    <div>
      <div class="border-t border-gray-200 pt-4 sm:flex sm:items-center sm:justify-between">
        <form id="filter-form" phx-change="filter">
          <div class="text-gray-800 text-sm inline-flex items-center">
            <div class="relative mt-2 rounded-md shadow-sm flex">
              <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                <Heroicons.magnifying_glass class="feather mr-1 dark:text-gray-300" />
              </div>
              <input
                type="text"
                name="filter-text"
                id="filter-text"
                class="pl-8 shadow-sm dark:bg-gray-900 dark:text-gray-300 focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800"
                placeholder="Search Properties"
                value={@filter_text}
              />
            </div>

            <Heroicons.backspace
              :if={String.trim(@filter_text) != ""}
              class="feather ml-2 cursor-pointer hover:text-red-500 dark:text-gray-300 dark:hover:text-red-500 mt-2"
              phx-click="reset-filter-text"
              id="reset-filter"
            />
          </div>
        </form>
        <div class="mt-4 flex sm:ml-4 sm:mt-0">
          <PlausibleWeb.Components.Generic.button phx-click="add-prop">
            + Add Property
          </PlausibleWeb.Components.Generic.button>
        </div>
      </div>
      <%= if is_list(@props) && length(@props) > 0 do %>
        <ul id="allowed-props" class="mt-12 divide-gray-200 divide-y dark:divide-gray-600">
          <li :for={{prop, index} <- Enum.with_index(@props)} id={"prop-#{index}"} class="flex py-4">
            <span class="flex-1 truncate font-medium text-sm text-gray-800 dark:text-gray-200">
              <%= prop %>
            </span>
            <button
              id={"disallow-prop-#{prop}"}
              data-confirm={delete_confirmation_text(prop)}
              phx-click="disallow-prop"
              phx-value-prop={prop}
              class="w-4 h-4 text-red-600 hover:text-red-700"
              aria-label={"Remove #{prop} property"}
            >
              <Heroicons.trash class="feather feather-sm" />
            </button>
          </li>
        </ul>
      <% else %>
        <p class="text-sm text-gray-800 dark:text-gray-200 mt-12 mb-8 text-center">
          <span :if={String.trim(@filter_text) != ""}>
            No properties found for this site. Please refine or
            <a
              class="text-indigo-500 cursor-pointer underline"
              phx-click="reset-filter-text"
              id="reset-filter-hint"
            >
              reset your search.
            </a>
          </span>
          <span :if={String.trim(@filter_text) == "" && Enum.empty?(@props)}>
            No properties configured for this site.
          </span>
        </p>
      <% end %>
    </div>
    """
  end

  defp delete_confirmation_text(prop) do
    """
    Are you sure you want to remove the following property:

    #{prop}

    This will just affect the UI, all of your analytics data will stay intact.
    """
  end
end
