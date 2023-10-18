defmodule PlausibleWeb.Components.Generic do
  @moduledoc """
  Generic reusable components
  """
  use Phoenix.Component

  attr(:slug, :string, required: true)

  def docs_info(assigns) do
    ~H"""
    <a href={"https://plausible.io/docs/#{@slug}"} rel="noreferrer" target="_blank">
      <Heroicons.information_circle class="text-gray-400 w-6 h-6 absolute top-0 right-0 text-gray-400" />
    </a>
    """
  end

  attr(:title, :string, default: "Notice")
  attr(:size, :atom, default: :sm)
  attr(:rest, :global)
  slot(:inner_block)

  def notice(assigns) do
    ~H"""
    <div class="rounded-md bg-yellow-50 dark:bg-yellow-100 p-4" {@rest}>
      <div class="flex">
        <div :if={@size !== :xs} class="flex-shrink-0">
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
          <h3
            :if={@size !== :xs}
            class={"text-#{@size} font-medium text-yellow-800 dark:text-yellow-900 mb-2"}
          >
            <%= @title %>
          </h3>
          <div class={"text-#{@size} text-yellow-700 dark:text-yellow-800"}>
            <p>
              <%= render_slot(@inner_block) %>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :any, default: nil
  attr :href, :string, required: true
  attr :new_tab, :boolean, default: false
  attr :class, :string, default: ""
  slot :inner_block

  def styled_link(assigns) do
    ~H"""
    <.unstyled_link
      new_tab={@new_tab}
      href={@href}
      class="text-indigo-600 hover:text-indigo-700 dark:text-indigo-500 dark:hover:text-indigo-600"
    >
      <%= render_slot(@inner_block) %>
    </.unstyled_link>
    """
  end

  slot :button, required: true do
    attr :class, :string
  end

  slot :panel, required: true do
    attr :class, :string
  end

  def dropdown(assigns) do
    ~H"""
    <div class="flex justify-center">
      <div
        x-data="dropdown"
        x-on:keydown.escape.prevent.stop="close($refs.button)"
        x-on:focusin.window="! $refs.panel.contains($event.target) && close()"
        x-id="['dropdown-button']"
        class="relative"
      >
        <button
          x-ref="button"
          x-on:click="toggle()"
          x-bind:aria-expanded="open"
          x-bind:aria-controls="$id('dropdown-button')"
          type="button"
          class={List.first(@button).class}
        >
          <%= render_slot(List.first(@button)) %>
        </button>
        <div
          x-ref="panel"
          x-show="open"
          x-transition.origin.top.left
          x-on:click.outside="close($refs.button)"
          x-on:click="onPanelClick"
          x-bind:id="$id('dropdown-button')"
          style="display: none;"
          class={List.first(@panel).class}
        >
          <%= render_slot(List.first(@panel)) %>
        </div>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :new_tab, :boolean, default: false
  slot :inner_block, required: true

  def dropdown_link(assigns) do
    ~H"""
    <.unstyled_link
      new_tab={@new_tab}
      href={@href}
      class="w-full justify-between text-gray-700 dark:text-gray-300 block px-3.5 py-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-gray-100"
    >
      <%= render_slot(@inner_block) %>
    </.unstyled_link>
    """
  end

  attr :href, :string, required: true
  attr :new_tab, :boolean, default: false
  attr :class, :string, default: ""
  attr :id, :any, default: nil
  slot :inner_block

  def unstyled_link(assigns) do
    if assigns[:new_tab] do
      assigns = assign(assigns, :icon_class, icon_class(assigns))

      ~H"""
      <.link
        id={@id}
        class={[
          "inline-flex items-center gap-x-0.5",
          @class
        ]}
        href={@href}
        target="_blank"
        rel="noopener noreferrer"
      >
        <%= render_slot(@inner_block) %>
        <Heroicons.arrow_top_right_on_square class={["opacity-60", @icon_class]} />
      </.link>
      """
    else
      ~H"""
      <.link class={@class} href={@href}>
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
