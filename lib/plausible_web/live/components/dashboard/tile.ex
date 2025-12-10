defmodule PlausibleWeb.Components.Dashboard.Tile do
  @moduledoc """
  Components for rendering dashboard tile contents.
  """

  use PlausibleWeb, :component

  attr :id, :string, required: true
  attr :title, :string, required: true
  # Optimistic rendering requires preventing LV patching of
  # title and tabs. The update of those is handled by `tab` 
  # widget hook.
  attr :connected?, :boolean, required: true

  slot :tabs
  slot :inner_block, required: true

  def tile(assigns) do
    ~H"""
    <div data-tile id={@id}>
      <div class="w-full flex justify-between h-full">
        <div id={@id <> "-title"} class="flex gap-x-1" phx-update="ignore">
          <h3 data-title class="font-bold dark:text-gray-100">{@title}</h3>
        </div>

        <div
          :if={@tabs != []}
          id={@id <> "-tabs"}
          phx-update="ignore"
          phx-hook="DashboardTabs"
          class="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2 items-baseline"
        >
          {render_slot(@tabs)}
        </div>
      </div>

      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :active, :string, required: true
  attr :target, :any, required: true

  def tab(assigns) do
    assigns =
      assign(assigns,
        active_classes:
          "text-indigo-600 dark:text-indigo-500 font-bold underline decoration-2 decoration-indigo-600 dark:decoration-indigo-500",
        inactive_classes: "hover:text-indigo-700 dark:hover:text-indigo-400 cursor-pointer"
      )

    ~H"""
    <button
      class="rounded-sm truncate text-left transition-colors duration-150"
      data-tab={@value}
      data-label={@label}
      data-storage-key="pageTab"
      data-active-classes={@active_classes}
      data-inactive-classes={@inactive_classes}
      phx-click="set-tab"
      phx-value-tab={@value}
      phx-target={@target}
    >
      <span class={if(@value == @active, do: @active_classes, else: @inactive_classes)}>
        {@label}
      </span>
    </button>
    """
  end
end
