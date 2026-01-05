defmodule PlausibleWeb.Components.Dashboard.Tile do
  @moduledoc """
  Components for rendering dashboard tile contents.
  """

  use PlausibleWeb, :component

  attr :id, :string, required: true
  attr :class, :string, default: ""
  attr :title, :string, required: true
  attr :height, :integer, required: true
  attr :connected?, :boolean, required: true
  attr :target, :any, required: true

  slot :tabs
  slot :inner_block, required: true

  def tile(assigns) do
    ~H"""
    <div class={[@class, "group overflow-x-hidden"]} data-tile id={@id}>
      <div class="w-full flex justify-between h-full">
        <div id={@id <> "-title"} class="flex gap-x-1" phx-update="ignore">
          <h3 data-title class="font-bold dark:text-gray-100">{@title}</h3>
        </div>

        <div
          :if={@tabs != []}
          id={@id <> "-tabs"}
          phx-hook="DashboardTabs"
          phx-target={@target}
          class="tile-tabs flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2 items-baseline"
        >
          {render_slot(@tabs)}
        </div>
      </div>

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
    <button
      class="rounded-sm truncate text-left transition-colors duration-150"
      data-tab-key={@tab_key}
      data-report-label={@report_label}
      data-storage-key="pageTab"
      data-target={@target}
    >
      <span
        {@data_attrs}
        class="data-[active=true]:text-indigo-600 data-[active=true]:dark:text-indigo-500 data-[active=true]:font-bold data-[active=true]:underline data-[active=true]:decoration-2 data-[active=true]:decoration-indigo-600 data-[active=true]:dark:decoration-indigo-500 data-[active=false]:hover:text-indigo-700 data-[active=false]:dark:hover:text-indigo-400 data-[active=false]:cursor-pointer"
      >
        {@report_label}
      </span>
    </button>
    """
  end
end
