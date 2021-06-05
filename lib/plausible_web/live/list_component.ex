defmodule PlausibleWeb.ListComponent do
  use PlausibleWeb, :live_component

  defp bar(item, list, bar_color) do
    max_value = List.first(list)[:count]
    width = item[:count] / max_value * 100
    assigns = [width: width, bar_color: bar_color]

    ~L"""
    <div class="<%= bar_color %>" style="width: <%= width %>%; height: 30px;"></div>
    """
  end

  def render(assigns) do
    ~L"""
      <div class="relative p-4 bg-white rounded shadow-xl stats-item dark:bg-gray-825" style="height: 436px">
        <%= if @list do %>
          <h3 class="font-bold dark:text-gray-100"><%= @title %></h3>
          <div class="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span><%= @key_label %></span>
            <span><%= @value_label %></span>
          </div>
          <%= for item <- @list do %>
            <div class="flex items-center justify-between my-1 text-sm">
              <div class="w-full h-8" style="max-width: calc(100% - 4rem)">
                <%= bar(item, @list, @bar_color) %>
                <span class="flex px-2 group dark:text-gray-300" style="margin-top: -26px" >
                  <span class="block truncate hover:underline">
                    <%= item[:name] %>
                  </span>
                </span>
              </div>
              <span class="font-medium dark:text-gray-200"><%= PlausibleWeb.StatsView.large_number_format(item[:count]) %></span>
            </div>
          <% end %>
        <% else %>
          <div class="mx-auto loading mt-44"><div></div></div>
        <% end %>
      </div>
    """
  end
end
