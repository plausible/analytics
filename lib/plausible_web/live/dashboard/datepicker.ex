defmodule PlausibleWeb.Live.Dashboard.DatePicker do
  @moduledoc """
  Pages breakdown component.
  """

  use PlausibleWeb, :live_component

  alias Plausible.Stats.Dashboard
  alias PlausibleWeb.Components.PrimaDropdown
  import PlausibleWeb.Components.Dashboard.Base
  alias Plausible.Stats.Dashboard.Utils

  @options Dashboard.Periods.all()

  def update(assigns, socket) do
    selected_label =
      Enum.find(@options, fn {_, input_date_range, _} ->
        input_date_range == assigns.params.input_date_range
      end)
      |> elem(2)

    socket =
      assign(socket,
        site: assigns.site,
        params: assigns.params,
        options: @options,
        selected_label: selected_label
      )

    {:ok, socket}
  end

  def render(assigns) do
    # @site @params @myself @connected?
    ~H"""
    <div class="min-w-36 md:relative lg:w-48 z-[99]">
      <PrimaDropdown.dropdown id="datepicker-prima-dropdown">
        <PrimaDropdown.dropdown_trigger as={&trigger_button/1}>
          <span class="truncate block font-medium">
            {@selected_label}
          </span>
          <Heroicons.chevron_down mini class="size-4 mt-0.5" />
        </PrimaDropdown.dropdown_trigger>

        <PrimaDropdown.dropdown_menu class="flex flex-col gap-0.5 p-1 focus:outline-hidden rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black/5 font-medium text-gray-800 dark:text-gray-200">
          <PrimaDropdown.dropdown_item
            :for={{storage_key, input_date_range, label} <- @options}
            as={&date_picker_option/1}
            class="dashboard-navigation-link"
            id="dashboard-navigation-link"
            args={%{
              storage_key: storage_key,
              patch: Utils.dashboard_route(@site, @params, update_params: [input_date_range: input_date_range]),
              label: label
            }}
          >
            {label}
          </PrimaDropdown.dropdown_item>
        </PrimaDropdown.dropdown_menu>
      </PrimaDropdown.dropdown>
    </div>
    """
  end

  attr :args, :map, required: true
  attr :rest, :global
  slot :inner_block, required: true

  defp date_picker_option(assigns) do
    ~H"""
    <.dashboard_link
      id={"date-picker-option-#{@args.storage_key}"}
      class="flex items-center justify-between px-4 py-2.5 text-sm leading-tight whitespace-nowrap rounded-md cursor-pointer hover:bg-gray-100 hover:text-gray-900 dark:hover:bg-gray-700 dark:hover:text-gray-100 focus-within:bg-gray-100 focus-within:text-gray-900 dark:focus-within:bg-gray-700 dark:focus-within:text-gray-100"
      to={@args.patch}
      data-label={@args.label}
      data-shorthand={@args.storage_key}
    >
      {render_slot(@inner_block)}
    </.dashboard_link>
    """
  end

  attr :rest, :global
  slot :inner_block, required: true

  defp trigger_button(assigns) do
    ~H"""
    <button
      class="flex items-center rounded text-sm leading-tight h-9 transition-all duration-150 bg-white dark:bg-gray-750 shadow-sm text-gray-800 dark:text-gray-200 dark:hover:bg-gray-700 justify-between px-2 w-full"
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
