defmodule PlausibleWeb.Components.Site.Feature do
  @moduledoc """
  Phoenix Component for rendering a user-facing feature toggle
  capable of flipping booleans in `Plausible.Site` via the `toggle_feature` controller action.
  """
  use PlausibleWeb, :view

  attr :site, Plausible.Site, required: true
  attr :setting, :atom, required: true
  attr :label, :string, required: true
  attr :conn, Plug.Conn, required: true
  slot :inner_block

  def toggle(assigns) do
    ~H"""
    <div>
      <div class="mt-4 mb-8 flex items-center">
        <%= if Map.fetch!(@site, @setting) do %>
          <.button_active to={target(@site, @setting, @conn, false)} />
        <% else %>
          <.button_inactive to={target(@site, @setting, @conn, true)} />
        <% end %>
        <span class="ml-2 text-sm font-medium text-gray-900 leading-5 dark:text-gray-100">
          <%= @label %>
        </span>
      </div>
      <div :if={Map.fetch!(@site, @setting)}>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def target(site, setting, conn, set_to) when is_boolean(set_to) do
    r = conn.request_path
    Routes.site_path(conn, :update_feature_visibility, site.domain, setting, r: r, set: set_to)
  end

  def button_active(assigns) do
    ~H"""
    <%= button(to: @to, method: :put, class: "bg-indigo-600 relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full cursor-pointer transition-colors ease-in-out duration-200 focus:outline-none focus:ring") do %>
      <span class="translate-x-5 inline-block h-5 w-5 rounded-full bg-white dark:bg-gray-800 shadow transform transition ease-in-out duration-200">
      </span>
    <% end %>
    """
  end

  def button_inactive(assigns) do
    ~H"""
    <%= button(to: @to, method: :put, class: "bg-gray-200 dark:bg-gray-700 relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full cursor-pointer transition-colors ease-in-out duration-200 focus:outline-none focus:ring") do %>
      <span class="translate-x-0 inline-block h-5 w-5 rounded-full bg-white dark:bg-gray-800 shadow transform transition ease-in-out duration-200">
      </span>
    <% end %>
    """
  end
end
