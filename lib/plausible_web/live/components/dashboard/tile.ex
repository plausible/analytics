defmodule PlausibleWeb.Components.Dashboard.Tile do
  @moduledoc """
  Components for rendering dashboard tile contents.
  """

  use PlausibleWeb, :component
  alias PlausibleWeb.Components.Dashboard.Base

  attr :id, :string, required: true
  attr :class, :string, default: ""
  attr :title, :string, required: true
  attr :height, :integer, required: true
  attr :connected?, :boolean, required: true
  attr :details_route, :string, required: true
  attr :target, :any, required: true

  slot :warnings
  slot :tabs
  slot :inner_block, required: true

  def tile(assigns) do
    ~H"""
    <div
      data-tile
      id={@id}
      class="relative min-h-[430px] w-full p-5 flex flex-col bg-white dark:bg-gray-900 shadow-sm rounded-md md:min-h-initial md:h-27.25rem"
    >
      <%!-- reportheader --%>
      <div class="w-full flex justify-between border-b border-gray-200 dark:border-gray-750">
        <div class="flex gap-x-3">
          <div
            :if={@tabs != []}
            id={@id <> "-tabs"}
            phx-hook="DashboardTabs"
            phx-target={@target}
            class="tile-tabs flex items-baseline gap-x-3.5 text-xs font-medium text-gray-500 dark:text-gray-400"
          >
            {render_slot(@tabs)}
          </div>
          <div class="group-[.phx-navigation-loading]:hidden group-has-[.tile-tabs.phx-hook-loading]:hidden">
            {render_slot(@warnings)}
          </div>
        </div>
        <.details_link details_route={@details_route} path="/pages" />
      </div>
      <%!-- reportbody --%>
      <div
        class="w-full flex-col justify-center group-[.phx-navigation-loading]:flex group-has-[.tile-tabs.phx-hook-loading]:flex hidden"
        style={"min-height: #{@height}px;"}
      >
        <div class="mx-auto loading">
          <div></div>
        </div>
      </div>

      <div class="group-[.phx-navigation-loading]:hidden group-has-[.tile-tabs.phx-hook-loading]:hidden">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :report_label, :string, required: true
  attr :tab_key, :string, required: true
  attr :active_tab, :string, required: true
  attr :target, :any, required: true

  def tab(assigns) do
    assigns =
      assign(
        assigns,
        data_attrs:
          if(assigns.tab_key == assigns.active_tab,
            do: %{"data-active": "true"},
            else: %{"data-active": "false"}
          )
      )

    ~H"""
    <div
      {@data_attrs}
      class="-mb-px pb-4 data-[active=true]:border-b-2 data-[active=true]:border-gray-900 data-[active=true]:dark:border-gray-100"
    >
      <button
        class="group/tab flex rounded-sm"
        data-tab-key={@tab_key}
        data-report-label={@report_label}
        data-storage-key="pageTab"
        data-target={@target}
      >
        <span
          {@data_attrs}
          class="
            truncate text-left text-xs uppercase text-gray-500 dark:text-gray-400 font-semibold cursor-pointer
            data-[active=false]:group-hover/tab:text-gray-800
            data-[active=false]:dark:group-hover/tab:text-gray-200
            data-[active=true]:text-gray-900
            data-[active=true]:dark:text-gray-100
            data-[active=true]:font-bold
            data-[active=true]:font-bold
            data-[active=true]:tracking-[-.01em]"
        >
          {@report_label}
        </span>
      </button>
    </div>
    """
  end

  defp details_link(assigns) do
    ~H"""
    <Base.dashboard_link
      class="flex mt-px text-gray-500 dark:text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors duration-150"
      to={@details_route}
    >
      <svg
        class="feather"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3" />
      </svg>
    </Base.dashboard_link>
    """
  end
end
