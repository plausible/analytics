defmodule PlausibleWeb.Live.Dashboard.Pages do
  @moduledoc """
  Pages breakdown component.
  """

  use PlausibleWeb, :live_component

  alias PlausibleWeb.Components.Dashboard.Base
  alias PlausibleWeb.Components.Dashboard.Tile

  @tabs [
    {"pages", "Top Pages"},
    {"entry-pages", "Entry Pages"},
    {"exit-pages", "Exit Pages"}
  ]

  @tab_labels Map.new(@tabs)

  def update(assigns, socket) do
    active_tab = assigns.user_prefs["pages_tab"] || "pages"

    socket =
      assign(socket,
        site: assigns.site,
        tabs: @tabs,
        tab_labels: @tab_labels,
        active_tab: active_tab
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <Tile.tile id="breakdown-tile-pages" title={@tab_labels[@active_tab]}>
        <:tabs>
          <Tile.tab
            :for={{value, label} <- @tabs}
            label={label}
            value={value}
            active={@active_tab}
            target={@myself}
          />
        </:tabs>

        <div class="mx-auto font-medium text-gray-500 dark:text-gray-400">
          <Base.dashboard_link site={@site} href="?f=is,source,Direct / None">
            Filter by source Direct / None
          </Base.dashboard_link>
        </div>
      </Tile.tile>
    </div>
    """
  end

  def handle_event("set-tab", %{"tab" => tab}, socket) do
    if tab != socket.assigns.active_tab do
      socket = assign(socket, :active_tab, tab)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
end
