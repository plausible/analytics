defmodule PlausibleWeb.Components.Generic do
  @moduledoc """
  Generic reusable components
  """
  use Phoenix.Component, global_prefixes: ~w(x-)

  @notice_themes %{
    gray: %{
      bg: "bg-white dark:bg-gray-800",
      icon: "text-gray-400",
      title_text: "text-gray-800 dark:text-gray-400",
      body_text: "text-gray-700 dark:text-gray-500 leading-5"
    },
    yellow: %{
      bg: "bg-yellow-50 dark:bg-yellow-100",
      icon: "text-yellow-400",
      title_text: "text-sm text-yellow-800 dark:text-yellow-900",
      body_text: "text-sm text-yellow-700 dark:text-yellow-800 leading-5"
    },
    red: %{
      bg: "bg-red-100",
      icon: "text-red-700",
      title_text: "text-sm text-red-800 dark:text-red-900",
      body_text: "text-sm text-red-700 dark:text-red-800"
    }
  }

  @button_themes %{
    "primary" => "bg-indigo-600 text-white hover:bg-indigo-700 focus-visible:outline-indigo-600",
    "bright" =>
      "border border-gray-200 bg-gray-100 dark:bg-gray-300 text-gray-800 hover:bg-gray-200 focus-visible:outline-gray-100",
    "danger" =>
      "border border-gray-300 dark:border-gray-500 text-red-700 bg-white dark:bg-gray-900 hover:text-red-500 dark:hover:text-red-400 focus:border-blue-300 dark:text-red-500 active:text-red-800"
  }

  @button_base_class "whitespace-nowrap truncate inline-flex items-center justify-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700"

  attr(:type, :string, default: "button")
  attr(:theme, :string, default: "primary")
  attr(:class, :string, default: "")
  attr(:disabled, :boolean, default: false)
  attr(:mt?, :boolean, default: true)
  attr(:rest, :global, include: ~w(name))

  slot(:inner_block)

  def button(assigns) do
    assigns =
      assign(assigns,
        button_base_class: @button_base_class,
        theme_class: @button_themes[assigns.theme]
      )

    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        @mt? && "mt-6",
        @button_base_class,
        @theme_class,
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr(:href, :string, required: true)
  attr(:class, :string, default: "")
  attr(:theme, :string, default: "primary")
  attr(:disabled, :boolean, default: false)
  attr(:method, :string, default: "get")
  attr(:mt?, :boolean, default: true)
  attr(:rest, :global)

  slot(:inner_block)

  def button_link(assigns) do
    extra =
      if assigns.method == "get" do
        []
      else
        [
          "data-csrf": Phoenix.Controller.get_csrf_token(),
          "data-method": assigns.method,
          "data-to": assigns.href
        ]
      end

    assigns = assign(assigns, extra: extra)

    theme_class =
      if assigns.disabled do
        "bg-gray-400 text-white dark:text-white dark:text-gray-400 dark:bg-gray-700 cursor-not-allowed"
      else
        @button_themes[assigns.theme]
      end

    onclick =
      if assigns.disabled do
        "return false;"
      else
        assigns[:onclick]
      end

    assigns =
      assign(assigns,
        onclick: onclick,
        button_base_class: @button_base_class,
        theme_class: theme_class
      )

    ~H"""
    <.link
      href={@href}
      onclick={@onclick}
      class={[
        @mt? && "mt-6",
        @button_base_class,
        @theme_class,
        @class
      ]}
      {@extra}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr(:slug, :string, required: true)
  attr(:class, :string, default: nil)

  def docs_info(assigns) do
    ~H"""
    <a href={"https://plausible.io/docs/#{@slug}"} rel="noopener noreferrer" target="_blank">
      <Heroicons.information_circle class={[
        "text-gray-500 dark:text-indigo-500 w-6 h-6 stroke-2 hover:text-indigo-500 dark:hover:text-indigo-300",
        @class
      ]} />
    </a>
    """
  end

  attr(:title, :any, default: nil)
  attr(:theme, :atom, default: :yellow)
  attr(:dismissable_id, :any, default: nil)
  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:inner_block)

  def notice(assigns) do
    assigns = assign(assigns, :theme, Map.fetch!(@notice_themes, assigns.theme))

    ~H"""
    <div id={@dismissable_id} class={[@dismissable_id && "hidden"]}>
      <div class={["rounded-md p-4 relative", @theme.bg, @class]} {@rest}>
        <button
          :if={@dismissable_id}
          class={"absolute right-0 top-0 m-2 #{@theme.title_text}"}
          onclick={"localStorage['notice_dismissed__#{@dismissable_id}'] = 'true'; document.getElementById('#{@dismissable_id}').classList.add('hidden')"}
        >
          <Heroicons.x_mark class="h-4 w-4 hover:stroke-2" />
        </button>
        <div class="flex">
          <div :if={@title} class="flex-shrink-0">
            <svg
              class={"h-5 w-5 #{@theme.icon}"}
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
          <div class={["w-full", @title && "ml-3"]}>
            <h3 :if={@title} class={"font-medium #{@theme.title_text} mb-2"}>
              {@title}
            </h3>
            <div class={"#{@theme.body_text}"}>
              <p>
                {render_slot(@inner_block)}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    <script :if={@dismissable_id} data-key={@dismissable_id}>
      const dismissId = document.currentScript.dataset.key
      const localStorageKey = `notice_dismissed__${dismissId}`

      if (localStorage[localStorageKey] !== 'true') {
        document.getElementById(dismissId).classList.remove('hidden')
      }
    </script>
    """
  end

  attr(:href, :string, default: "#")
  attr(:new_tab, :boolean, default: false)
  attr(:class, :string, default: "")
  attr(:rest, :global)
  attr(:method, :string, default: "get")
  slot(:inner_block)

  def styled_link(assigns) do
    ~H"""
    <.unstyled_link
      new_tab={@new_tab}
      href={@href}
      method={@method}
      class={"text-indigo-600 hover:text-indigo-700 dark:text-indigo-500 dark:hover:text-indigo-600 " <> @class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.unstyled_link>
    """
  end

  attr :class, :string, default: ""
  attr :id, :string, default: nil

  slot :button, required: true do
    attr(:class, :string)
  end

  slot :menu, required: true do
    attr(:class, :string)
  end

  def dropdown(assigns) do
    assigns = assign(assigns, :menu_class, assigns.menu |> List.first() |> Map.get(:class, ""))

    ~H"""
    <div
      id={@id}
      x-data="dropdown"
      x-on:keydown.escape.prevent.stop="close($refs.button)"
      class="relative inline-block text-left"
    >
      <button
        x-ref="button"
        x-on:click="toggle()"
        type="button"
        class={["py-2.5", List.first(@button).class]}
      >
        {render_slot(List.first(@button))}
      </button>
      <div
        x-show="open"
        x-cloak
        x-transition:enter="transition ease-out duration-100"
        x-transition:enter-start="opacity-0 scale-95"
        x-transition:enter-end="opacity-100 scale-100"
        x-transition:leave="transition ease-in duration-75"
        x-transition:leave-start="opacity-100 scale-100"
        x-transition:leave-end="opacity-0 scale-95"
        x-on:click.outside="close($refs.button)"
        style="display: none;"
        class={[
          "origin-top-right absolute z-50 right-0 mt-2 p-1.5 w-max rounded-md shadow-lg overflow-hidden bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none",
          @menu_class
        ]}
      >
        {render_slot(List.first(@menu))}
      </div>
    </div>
    """
  end

  attr(:href, :string)
  attr(:class, :string, default: "")
  attr(:id, :string, default: nil)
  attr(:new_tab, :boolean, default: false)
  attr(:disabled, :boolean, default: false)
  attr(:rest, :global, include: ~w(method))
  slot(:inner_block, required: true)

  @base_class "block rounded-lg text-sm/6 text-gray-900 ui-disabled:text-gray-500 dark:text-gray-100 dark:ui-disabled:text-gray-400 px-3.5 py-1.5"
  @clickable_class "hover:bg-gray-100 dark:hover:bg-gray-700"
  def dropdown_item(assigns) do
    assigns =
      if assigns[:disabled] do
        assign(assigns, :state, "disabled")
      else
        assign(assigns, :state, "")
      end

    if assigns[:href] && !assigns[:disabled] do
      assigns = assign(assigns, :class, [assigns[:class], @base_class, @clickable_class])

      ~H"""
      <.unstyled_link
        id={@id}
        class={@class}
        new_tab={@new_tab}
        href={@href}
        x-on:click="close()"
        data-ui-state={@state}
        {@rest}
      >
        {render_slot(@inner_block)}
      </.unstyled_link>
      """
    else
      assigns = assign(assigns, :class, [assigns[:class], @base_class])

      ~H"""
      <div data-ui-state={@state} class={@class}>
        {render_slot(@inner_block)}
      </div>
      """
    end
  end

  def dropdown_divider(assigns) do
    ~H"""
    <div class="mx-3.5 my-1 h-px border-0 bg-gray-950/5 sm:mx-3 dark:bg-white/10" role="separator">
    </div>
    """
  end

  attr(:href, :string, required: true)
  attr(:new_tab, :boolean, default: false)
  attr(:class, :string, default: nil)
  attr(:rest, :global)
  attr(:method, :string, default: "get")
  slot(:inner_block)

  def unstyled_link(assigns) do
    extra =
      if assigns.method == "get" do
        []
      else
        [
          "data-csrf": Phoenix.Controller.get_csrf_token(),
          "data-method": assigns.method,
          "data-to": assigns.href
        ]
      end

    assigns = assign(assigns, extra: extra)

    if assigns[:new_tab] do
      assigns = assign(assigns, :icon_class, icon_class(assigns))

      ~H"""
      <.link
        class={[
          "inline-flex items-center gap-x-0.5",
          @class
        ]}
        href={@href}
        target="_blank"
        rel="noopener noreferrer"
        {@extra}
        {@rest}
      >
        {render_slot(@inner_block)}
        <Heroicons.arrow_top_right_on_square class={["opacity-60", @icon_class]} />
      </.link>
      """
    else
      ~H"""
      <.link class={@class} href={@href} {@extra} {@rest}>{render_slot(@inner_block)}</.link>
      """
    end
  end

  attr(:class, :any, default: "")
  attr(:rest, :global)

  def spinner(assigns) do
    ~H"""
    <svg
      class={["animate-spin h-4 w-4 text-indigo-500", @class]}
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      {@rest}
    >
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4">
      </circle>
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      >
      </path>
    </svg>
    """
  end

  def settings_tiles(assigns) do
    ~H"""
    <div class="text-gray-900 leading-5 dark:text-gray-100">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :docs, :string, default: nil
  slot :inner_block, required: true
  slot :title, required: true
  slot :subtitle, required: true
  attr :feature_mod, :atom, default: nil
  attr :site, :any
  attr :conn, :any

  def tile(assigns) do
    ~H"""
    <div class="shadow bg-white dark:bg-gray-800 rounded-md mb-6">
      <header class="relative py-4 px-6">
        <.title>
          {render_slot(@title)}

          <.docs_info :if={@docs} slug={@docs} class="absolute top-4 right-4" />
        </.title>
        <div class="text-sm mt-px text-gray-500 dark:text-gray-400 leading-5">
          {render_slot(@subtitle)}
        </div>
        <%= if @feature_mod do %>
          <PlausibleWeb.Components.Site.Feature.toggle
            feature_mod={@feature_mod}
            site={@site}
            conn={@conn}
          />
        <% end %>
        <div class="border-b dark:border-gray-700 pb-4"></div>
      </header>

      <div class="pb-4 px-6">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr(:sticky?, :boolean, default: true)
  slot(:inner_block, required: true)
  slot(:tooltip_content, required: true)

  def tooltip(assigns) do
    wrapper_data =
      if assigns[:sticky?], do: "{sticky: false, hovered: false}", else: "{hovered: false}"

    show_inner = if assigns[:sticky?], do: "hovered || sticky", else: "hovered"

    assigns = assign(assigns, wrapper_data: wrapper_data, show_inner: show_inner)

    ~H"""
    <div x-data={@wrapper_data} class="tooltip-wrapper w-full relative z-[1000]">
      <div
        x-cloak
        x-show={@show_inner}
        class="tooltip-content z-[1000] bg-gray-900 rounded text-white absolute bottom-24 sm:bottom-7 left-0 sm:w-72 p-4 text-sm font-medium"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0"
      >
        {render_slot(List.first(@tooltip_content))}
      </div>
      <div
        x-on:click="sticky = true; hovered = true"
        x-on:click.outside="sticky = false; hovered = false"
        x-on:mouseover="hovered = true"
        x-on:mouseout="hovered = false"
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr(:rest, :global, include: ~w(fill stroke stroke-width))
  attr(:name, :atom, required: true)
  attr(:outline, :boolean, default: true)
  attr(:solid, :boolean, default: false)
  attr(:mini, :boolean, default: false)

  def dynamic_icon(assigns) do
    apply(Heroicons, assigns.name, [assigns])
  end

  attr(:width, :integer, default: 100)
  attr(:height, :integer, default: 100)
  attr(:id, :string, default: "shuttle")

  defp icon_class(link_assigns) do
    classes = List.wrap(link_assigns[:class]) |> Enum.join(" ")

    if String.contains?(classes, "text-sm") or
         String.contains?(classes, "text-xs") do
      ["w-3 h-3"]
    else
      ["w-4 h-4"]
    end
  end

  slot(:item, required: true)

  def focus_list(assigns) do
    ~H"""
    <ol class="list-disc space-y-1 ml-4 text-sm">
      <li :for={item <- @item} class="marker:text-indigo-700 dark:marker:text-indigo-700">
        {render_slot(item)}
      </li>
    </ol>
    """
  end

  slot :title
  slot :subtitle
  slot :inner_block, required: true
  slot :footer
  attr :rest, :global

  def focus_box(assigns) do
    ~H"""
    <div
      class="bg-white w-full max-w-lg mx-auto dark:bg-gray-800 text-gray-900 dark:text-gray-100 shadow-md rounded-md mt-12"
      {@rest}
    >
      <div class="p-8">
        <.title :if={@title != []}>
          {render_slot(@title)}
        </.title>
        <div></div>

        <div :if={@subtitle != []} class="text-sm mt-4 leading-6">
          {render_slot(@subtitle)}
        </div>

        <div :if={@title != []} class="mt-8">
          {render_slot(@inner_block)}
        </div>

        <div :if={@title == []}>
          {render_slot(@inner_block)}
        </div>
      </div>
      <div
        :if={@footer != []}
        class="flex flex-col dark:text-gray-200 border-t border-gray-300 dark:border-gray-700"
      >
        <div class="p-8">
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    """
  end

  attr :rest, :global
  attr :width, :string, default: "min-w-full"
  attr :rows, :list, default: []
  attr :row_attrs, :any, default: nil
  slot :thead, required: false
  slot :tbody, required: true
  slot :inner_block, required: false

  def table(assigns) do
    ~H"""
    <table :if={not Enum.empty?(@rows)} class={@width} {@rest}>
      <thead :if={@thead != []}>
        <tr class="border-b border-gray-200 dark:border-gray-700">
          {render_slot(@thead)}
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
        <tr :for={item <- @rows} {if @row_attrs, do: @row_attrs.(item), else: %{}}>
          {render_slot(@tbody, item)}
        </tr>
        {render_slot(@inner_block)}
      </tbody>
    </table>
    """
  end

  slot :inner_block, required: true
  attr :truncate, :boolean, default: false
  attr :max_width, :string, default: ""
  attr :height, :string, default: ""
  attr :actions, :boolean, default: nil
  attr :hide_on_mobile, :boolean, default: nil
  attr :rest, :global

  def td(assigns) do
    max_width =
      cond do
        assigns.max_width != "" -> assigns.max_width
        assigns.truncate -> "max-w-sm"
        true -> ""
      end

    assigns = assign(assigns, max_width: max_width)

    ~H"""
    <td
      class={[
        @height,
        "text-sm px-6 py-3 first:pl-0 last:pr-0 whitespace-nowrap",
        @truncate && "truncate",
        @max_width,
        @actions && "flex text-right justify-end",
        @hide_on_mobile && "hidden md:table-cell"
      ]}
      {@rest}
    >
      <div :if={@actions} class="flex gap-2">
        {render_slot(@inner_block)}
      </div>
      <div :if={!@actions}>
        {render_slot(@inner_block)}
      </div>
    </td>
    """
  end

  slot :inner_block, required: true
  attr :invisible, :boolean, default: false
  attr :hide_on_mobile, :boolean, default: nil

  def th(assigns) do
    class =
      if assigns[:invisible] do
        "invisible"
      else
        "px-6 first:pl-0 last:pr-0 py-3 text-left text-sm font-medium"
      end

    assigns = assign(assigns, class: class)

    ~H"""
    <th scope="col" class={[@hide_on_mobile && "hidden md:table-cell", @class]}>
      {render_slot(@inner_block)}
    </th>
    """
  end

  attr :set_to, :boolean, default: false
  attr :disabled?, :boolean, default: false
  slot :inner_block, required: true

  def toggle_submit(assigns) do
    ~H"""
    <div class="mt-4 mb-2 flex items-center">
      <button
        type="submit"
        class={[
          "relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full transition-colors ease-in-out duration-200 focus:outline-none focus:ring",
          if(@set_to, do: "bg-indigo-600", else: "bg-gray-200 dark:bg-gray-700"),
          if(@disabled?, do: "cursor-not-allowed")
        ]}
        disabled={@disabled?}
      >
        <span
          aria-hidden="true"
          class={[
            "inline-block h-5 w-5 rounded-full bg-white dark:bg-gray-800 shadow transform transition ease-in-out duration-200",
            if(@set_to, do: "translate-x-5", else: "translate-x-0")
          ]}
        />
      </button>

      <span class={[
        "ml-2 font-medium leading-5 text-sm",
        if(@disabled?,
          do: "text-gray-500 dark:text-gray-400",
          else: "text-gray-900 dark:text-gray-100"
        )
      ]}>
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  attr :href, :string, default: nil
  attr :rest, :global, include: ~w(method disabled)

  def edit_button(assigns) do
    if assigns[:href] do
      ~H"""
      <.unstyled_link href={@href} {@rest}>
        <Heroicons.pencil_square class="w-5 h-5 text-indigo-800 hover:text-indigo-500 dark:text-indigo-500 dark:hover:text-indigo-300" />
      </.unstyled_link>
      """
    else
      ~H"""
      <button {@rest}>
        <Heroicons.pencil_square class="w-5 h-5 text-indigo-800 hover:text-indigo-500 dark:text-indigo-500 dark:hover:text-indigo-300" />
      </button>
      """
    end
  end

  attr :href, :string, default: nil
  attr :rest, :global, include: ~w(method disabled)

  def delete_button(assigns) do
    if assigns[:href] do
      ~H"""
      <.unstyled_link href={@href} {@rest}>
        <Heroicons.trash class="w-5 h-5 text-red-800 hover:text-red-500 dark:text-red-500 dark:hover:text-red-400" />
      </.unstyled_link>
      """
    else
      ~H"""
      <button {@rest}>
        <Heroicons.trash class="w-5 h-5 text-red-800 hover:text-red-500 dark:text-red-500 dark:hover:text-red-400" />
      </button>
      """
    end
  end

  attr :filter_text, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :filtering_enabled?, :boolean, default: true
  slot :inner_block, required: false

  def filter_bar(assigns) do
    ~H"""
    <div class="mb-6 flex items-center justify-between">
      <div class="text-gray-800 inline-flex items-center">
        <div :if={@filtering_enabled?} class="relative rounded-md shadow-sm flex">
          <form id="filter-form" phx-change="filter" class="flex items-center">
            <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
              <Heroicons.magnifying_glass class="feather mr-1 dark:text-gray-300" />
            </div>
            <input
              type="text"
              name="filter-text"
              id="filter-text"
              class="w-36 sm:w-full pl-8 text-sm shadow-sm dark:bg-gray-900 dark:text-gray-300 focus:ring-indigo-500 focus:border-indigo-500 block border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800"
              placeholder={@placeholder}
              value={@filter_text}
            />

            <Heroicons.backspace
              :if={String.trim(@filter_text) != ""}
              class="feather ml-2 cursor-pointer hover:text-red-500 dark:text-gray-300 dark:hover:text-red-500"
              phx-click="reset-filter-text"
              id="reset-filter"
            />
          </form>
        </div>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot :inner_block, required: true
  attr :class, :any, default: nil

  def h2(assigns) do
    ~H"""
    <h2 class={[@class || "font-semibold leading-6 text-gray-900 dark:text-gray-100"]}>
      {render_slot(@inner_block)}
    </h2>
    """
  end

  slot :inner_block, required: true
  attr :class, :any, default: nil

  def title(assigns) do
    ~H"""
    <.h2 class={["text-lg font-medium text-gray-900 dark:text-gray-100 leading-7", @class]}>
      {render_slot(@inner_block)}
    </.h2>
    """
  end
end
