defmodule PlausibleWeb.Components.Generic do
  @moduledoc """
  Generic reusable components
  """
  use Phoenix.Component

  attr :title, :string, default: "Notice"
  attr :class, :string, default: ""
  slot :inner_block

  def notice(assigns) do
    ~H"""
    <div class={[
      "rounded-md bg-yellow-50 dark:bg-yellow-100 p-4",
      @class
    ]}>
      <div class="flex">
        <div class="flex-shrink-0">
          <svg
            class="h-5 w-5 text-yellow-400"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-yellow-800 dark:text-yellow-900"><%= @title %></h3>
          <div class="mt-2 text-sm text-yellow-700 dark:text-yellow-800">
            <p>
              <%= render_slot(@inner_block) %>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :new_tab, :boolean
  attr :class, :string, default: ""
  slot :inner_block

  def styled_link(assigns) do
    if assigns[:new_tab] do
      assigns = assign(assigns, :icon_class, icon_class(assigns))

      ~H"""
      <.link
        class={[
          "inline-flex items-center gap-x-0.5 text-indigo-600 hover:text-indigo-700 dark:text-indigo-500 dark:hover:text-indigo-600",
          @class
        ]}
        href={@href}
        target="_blank"
        rel="noopener noreferrer"
      >
        <%= render_slot(@inner_block) %>
        <Heroicons.arrow_top_right_on_square class={@icon_class} />
      </.link>
      """
    else
      ~H"""
      <.link
        class={[
          "text-indigo-600 hover:text-indigo-700 dark:text-indigo-500 dark:hover:text-indigo-600",
          @class
        ]}
        href={@href}
      >
        <%= render_slot(@inner_block) %>
      </.link>
      """
    end
  end

  defp icon_class(link_assigns) do
    if String.contains?(link_assigns[:class], "text-sm") do
      ["w-3 h-3"]
    else
      ["w-4 h-4"]
    end
  end
end
