defmodule PlausibleWeb.DropdownComponent do
  use PlausibleWeb, :live_component

  def period_name(period) do
    case period do
      "6mo" -> "Last 6 months"
      "12mo" -> "Last 12 months"
      _ -> "Unknown"
    end
  end

  def render(assigns) do
    ~L"""
    <div class="relative" style="height: 35.5px; width: 190px;">
      <div x-data="{open: false}" class="relative">
        <button @click="open = !open" @keydown.escape="isOpen = false" class="flex items-center justify-between w-full h-full px-4 py-2 pr-3 text-sm font-medium leading-tight text-gray-800 bg-white rounded shadow cursor-pointer dark:bg-gray-800 dark:text-gray-200">
          <%= period_name(@period) %>
        </button>
        <div x-show.transition="open" x-on:click.away="open = false" class="absolute right-0 z-50 w-40 py-2 mt-2 bg-white border rounded shadow-xl">
          <a href="?period=day" @click="open = false" class="flex items-center justify-between px-4 py-2 leading-tight md:text-sm hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100">Today</a>
          <a href="?period=realtime" @click="open = false" class="flex items-center justify-between px-4 py-2 leading-tight md:text-sm hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100">Realtime</a>
          <div class="py-2">
            <hr></hr>
          </div>
          <a href="?period=7d" @click="open = false" class="flex items-center justify-between px-4 py-2 leading-tight md:text-sm hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100">Last 7 days</a>
          <a href="?period=30d" @click="open = false" class="flex items-center justify-between px-4 py-2 leading-tight md:text-sm hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100">Last 30 days</a>
          <div class="py-2">
            <hr></hr>
          </div>
          <a href="?period=7d" @click="open = false" class="flex items-center justify-between px-4 py-2 leading-tight md:text-sm hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100">Month to date</a>
          <a href="?period=30d" @click="open = false" class="flex items-center justify-between px-4 py-2 leading-tight md:text-sm hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100">Last month</a>
          <div class="py-2">
            <hr></hr>
          </div>
          <%= live_patch "Last 6 months", to: "?period=6mo", class: "flex items-center justify-between px-4 py-2 leading-tight md:text-sm hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100", "@click": "open = false" %>
          <%= live_patch "Last 12 months", to: "?period=12mo", class: "flex items-center justify-between px-4 py-2 leading-tight md:text-sm hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100", "@click": "open = false" %>
        </div>
      </div>
    </div>
    """
  end
end
