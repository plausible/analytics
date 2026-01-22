defmodule PlausibleWeb.Live.Dashboard.Filters do
  @moduledoc """
  Filters and segments component.
  """

  use PlausibleWeb, :live_component

  import Plausible.Stats.Dashboard.Utils

  alias PlausibleWeb.Components.Dashboard.Base
  alias PlausibleWeb.Components.PrimaDropdown

  def update(assigns, socket) do
    socket =
      assign(socket, site: assigns.site, params: assigns.params, connected?: assigns.connected?)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <PrimaDropdown.dropdown id="datepicker-prima-dropdown">
        <PrimaDropdown.dropdown_trigger as={&trigger_button/1}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            aria-hidden="true"
            data-slot="icon"
            class="block h-4 w-4"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"
            >
            </path>
          </svg>
          <span class="truncate block font-medium">Filter</span>
        </PrimaDropdown.dropdown_trigger>

        <PrimaDropdown.dropdown_menu class="relative z-[9999] flex flex-col gap-0.5 p-1 focus:outline-hidden rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black/5 font-medium text-gray-800 dark:text-gray-200">
          <PrimaDropdown.dropdown_item as={&filter_option/1}>
            <Base.dashboard_link
              class="mt-px text-gray-500 dark:text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors duration-150"
              to={dashboard_route(@site, @params, path: "/filter/page")}
            >
              Page
            </Base.dashboard_link>
          </PrimaDropdown.dropdown_item>
        </PrimaDropdown.dropdown_menu>
      </PrimaDropdown.dropdown>
    </div>
    """
  end

  attr :args, :map, required: true
  attr :rest, :global
  slot :inner_block, required: true

  defp filter_option(assigns) do
    ~H"""
    {render_slot(@inner_block)}
    """
  end

  attr :rest, :global
  slot :inner_block, required: true

  defp trigger_button(assigns) do
    ~H"""
    <button
      class="flex items-center rounded text-sm leading-tight h-9 transition-all duration-150 text-gray-700 dark:text-gray-100 hover:bg-gray-200 dark:hover:bg-gray-900 justify-center gap-1 px-3"
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
