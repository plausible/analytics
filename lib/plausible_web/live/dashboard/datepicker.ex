defmodule PlausibleWeb.Live.Dashboard.DatePicker do
  @moduledoc """
  Pages breakdown component.
  """

  use PlausibleWeb, :live_component

  alias Plausible.Stats.{Dashboard, ParsedQueryParams}
  alias PlausibleWeb.Components.PrimaDropdown
  import PlausibleWeb.Components.Dashboard.Base
  alias Plausible.Stats.Dashboard.Utils

  @options Dashboard.Periods.all()

  def update(assigns, socket) do
    %ParsedQueryParams{input_date_range: input_date_range, relative_date: relative_date} =
      assigns.params

    selected_label = Dashboard.Periods.label_for(input_date_range, relative_date)

    {quick_navigation_dates, current_date_index} =
      quick_navigation_dates(assigns.site, input_date_range, relative_date)

    quick_navigation_labels =
      Enum.map(quick_navigation_dates, fn date ->
        Dashboard.Periods.label_for(input_date_range, date)
      end)

    socket =
      assign(socket,
        site: assigns.site,
        params: assigns.params,
        current_date_index: current_date_index,
        quick_navigation_dates: quick_navigation_dates,
        quick_navigation_labels: quick_navigation_labels,
        options: @options,
        selected_label: selected_label
      )

    {:ok, socket}
  end

  def render(assigns) do
    # @site @params @myself @connected?
    ~H"""
    <div
      id="datepicker"
      phx-hook="DatePicker"
      data-target={@myself}
      data-current-index={@current_date_index}
      data-dates={JSON.encode!(@quick_navigation_dates)}
      data-labels={JSON.encode!(@quick_navigation_labels)}
      class="flex shrink-0"
    >
      <div
        :if={@quick_navigation_dates != []}
        class="flex rounded shadow bg-white mr-2 sm:mr-4 cursor-pointer focus:z-10 dark:bg-gray-750"
      >
        <button
          id="prev-period"
          data-disabled={"#{@current_date_index == 0}"}
          class="
            data-[disabled=true]:text-gray-400
            data-[disabled=true]:dark:text-gray-600
            data-[disabled=true]:bg-gray-200
            data-[disabled=true]:dark:bg-gray-850
            data-[disabled=true]:cursor-not-allowed
            flex items-center px-1 sm:px-2 dark:text-gray-100 transition-colors duration-150 rounded-l hover:bg-gray-100 dark:hover:bg-gray-700 border-gray-300 dark:border-gray-500 focus:z-10
          "
        >
          <Heroicons.chevron_left class="size-3.5" />
        </button>
        <button
          id="next-period"
          data-disabled={"#{@current_date_index == length(@quick_navigation_dates) - 1}"}
          class="
            data-[disabled=true]:text-gray-400
            data-[disabled=true]:dark:text-gray-600
            data-[disabled=true]:bg-gray-200
            data-[disabled=true]:dark:bg-gray-850
            data-[disabled=true]:cursor-not-allowed
            flex items-center px-1 sm:px-2 dark:text-gray-100 transition-colors duration-150 rounded-r hover:bg-gray-100 dark:hover:bg-gray-700
          "
        >
          <Heroicons.chevron_right class="size-3.5" />
        </button>
      </div>
      <div class="min-w-36 md:relative lg:w-48 z-[99]">
        <PrimaDropdown.dropdown id="datepicker-prima-dropdown">
          <PrimaDropdown.dropdown_trigger as={&trigger_button/1}>
            <span id="period-label" class="truncate block font-medium">
              {@selected_label}
            </span>
            <Heroicons.chevron_down mini class="size-4 mt-0.5" />
          </PrimaDropdown.dropdown_trigger>

          <PrimaDropdown.dropdown_menu class="flex flex-col gap-0.5 p-1 focus:outline-hidden rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black/5 font-medium text-gray-800 dark:text-gray-200">
            <PrimaDropdown.dropdown_item
              :for={{storage_key, input_date_range} <- @options}
              as={&date_picker_option/1}
              class="dashboard-navigation-link"
              id="dashboard-navigation-link"
              args={
                %{
                  storage_key: storage_key,
                  patch:
                    Utils.dashboard_route(@site, @params,
                      update_params: [input_date_range: input_date_range]
                    )
                }
              }
            >
              {Dashboard.Periods.label_for(input_date_range, nil)}
            </PrimaDropdown.dropdown_item>
          </PrimaDropdown.dropdown_menu>
        </PrimaDropdown.dropdown>
      </div>
    </div>
    """
  end

  def handle_event("set-relative-date", %{"date" => date}, socket) do
    socket =
      socket
      |> push_patch(
        to:
          Utils.dashboard_route(socket.assigns.site, socket.assigns.params,
            update_params: [relative_date: Date.from_iso8601!(date)]
          )
      )

    {:noreply, socket}
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

  defp quick_navigation_dates(site, input_date_range, nil) do
    quick_navigation_dates(site, input_date_range, Plausible.Times.today(site.timezone))
  end

  defp quick_navigation_dates(site, input_date_range, relative_date)
       when input_date_range in [:day, :month, :year] do
    dates =
      -10..10
      |> Enum.map(fn n ->
        Date.shift(relative_date, [{input_date_range, n}])
      end)
      |> Enum.take_while(fn date ->
        not Date.after?(date, Plausible.Times.today(site.timezone))
      end)

    {dates, Enum.find_index(dates, &(&1 == relative_date))}
  end

  defp quick_navigation_dates(_, _, _), do: {[], nil}
end
