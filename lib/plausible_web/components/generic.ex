defmodule PlausibleWeb.Components.Generic do
  @moduledoc """
  Generic reusable components
  """
  use Phoenix.Component, global_prefixes: ~w(x-)

  import PlausibleWeb.Components.Icons

  @notice_themes %{
    gray: %{
      bg: "bg-gray-100 dark:bg-gray-800",
      icon: "text-gray-600 dark:text-gray-300",
      title_text: "text-sm text-gray-900 dark:text-gray-100",
      body_text: "text-sm text-gray-800 dark:text-gray-200 leading-5"
    },
    yellow: %{
      bg: "bg-yellow-100/60 dark:bg-yellow-900/40",
      icon: "text-yellow-500",
      title_text: "text-sm text-gray-900 dark:text-gray-100",
      body_text: "text-sm text-gray-600 dark:text-gray-100/60 leading-5"
    },
    red: %{
      bg: "bg-red-100 dark:bg-red-900/30",
      icon: "text-red-600 dark:text-red-500",
      title_text: "text-sm text-gray-900 dark:text-gray-100",
      body_text: "text-sm text-gray-600 dark:text-gray-100/60 leading-5"
    },
    white: %{
      bg: "bg-white dark:bg-gray-900 shadow-sm dark:shadow-none",
      icon: "text-gray-600 dark:text-gray-400",
      title_text: "text-sm text-gray-900 dark:text-gray-100",
      body_text: "text-sm text-gray-600 dark:text-gray-300 leading-5"
    }
  }

  @button_themes %{
    "primary" =>
      "bg-indigo-600 text-white hover:bg-indigo-700 focus-visible:outline-indigo-600 disabled:bg-indigo-400/60 disabled:dark:bg-indigo-600/30 disabled:dark:text-white/35",
    "secondary" =>
      "border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 hover:bg-gray-50 hover:text-gray-900 dark:hover:bg-gray-600 dark:hover:border-gray-600 dark:hover:text-white disabled:text-gray-700/40 dark:disabled:text-gray-500 dark:disabled:bg-gray-800 dark:disabled:border-gray-800",
    "yellow" =>
      "bg-yellow-600/90 text-white hover:bg-yellow-600 focus-visible:outline-yellow-600 disabled:bg-yellow-400/60 disabled:dark:bg-yellow-600/30 disabled:dark:text-white/35",
    "danger" =>
      "border border-gray-300 dark:border-gray-800 text-red-600 bg-white dark:bg-gray-800 hover:text-red-700 dark:hover:text-red-400 dark:text-red-500 active:text-red-800 disabled:text-red-700/40 disabled:hover:shadow-none dark:disabled:text-red-500/35 dark:disabled:bg-gray-800",
    "ghost" =>
      "text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-800 disabled:text-gray-500 disabled:dark:text-gray-600 disabled:hover:bg-transparent"
  }

  @button_base_class "whitespace-nowrap truncate inline-flex items-center justify-center gap-x-2 text-sm font-medium rounded-md cursor-pointer disabled:cursor-not-allowed"

  @button_sizes %{
    "sm" => "px-3 py-2",
    "md" => "px-3.5 py-2.5"
  }

  attr(:type, :string, default: "button")
  attr(:theme, :string, default: "primary")
  attr(:size, :string, default: "md")
  attr(:class, :string, default: "")
  attr(:disabled, :boolean, default: false)
  attr(:mt?, :boolean, default: true)
  attr(:rest, :global, include: ~w(name))

  slot(:inner_block)

  def button(assigns) do
    assigns =
      assign(assigns,
        button_base_class: @button_base_class,
        theme_class: @button_themes[assigns.theme],
        size_class: @button_sizes[assigns.size]
      )

    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        @mt? && "mt-6",
        @button_base_class,
        @size_class,
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
  attr(:size, :string, default: "md")
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
        "bg-gray-400 text-white transition-all duration-150 dark:text-white dark:text-gray-400 dark:bg-gray-700 cursor-not-allowed"
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
        theme_class: theme_class,
        size_class: @button_sizes[assigns.size]
      )

    ~H"""
    <.link
      href={@href}
      onclick={@onclick}
      class={[
        @mt? && "mt-6",
        @button_base_class,
        @size_class,
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
    <div class={@class}>
      <.tooltip enabled?={true} centered?={true}>
        <:tooltip_content>
          <span>Learn more</span>
        </:tooltip_content>
        <a
          href={"https://plausible.io/docs/#{@slug}"}
          rel="noopener noreferrer"
          target="_blank"
          class="inline-block"
        >
          <Heroicons.information_circle class="text-gray-400 dark:text-indigo-500 size-5 hover:text-indigo-500 dark:hover:text-indigo-400 transition-colors duration-150" />
        </a>
      </.tooltip>
    </div>
    """
  end

  attr(:title, :any, default: "")
  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:icon, required: true)
  slot(:inner_block)

  def upgrade(assigns) do
    ~H"""
    <div class={["rounded-md p-5 bg-gray-100 dark:bg-gray-800", @class]} {@rest}>
      <div class="flex flex-col gap-y-4">
        <div class="flex-shrink-0 bg-white dark:bg-gray-700 max-w-max rounded-md p-2 border border-gray-200 dark:border-gray-600 text-indigo-500">
          {render_slot(@icon)}
        </div>
        <div class="flex flex-col gap-y-2">
          <h3 class="font-medium text-gray-900 dark:text-gray-100">
            {@title}
          </h3>
          <p class="mb-1 text-sm text-gray-600 dark:text-gray-100/60 leading-normal">
            {render_slot(@inner_block)}
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr(:title, :any, default: nil)
  attr(:theme, :atom, default: :yellow)
  attr(:dismissable_id, :any, default: nil)
  attr(:show_icon, :boolean, default: true)
  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:inner_block)
  slot(:actions)
  slot(:icon)

  def notice(assigns) do
    assigns = assign(assigns, :theme, Map.fetch!(@notice_themes, assigns.theme))

    ~H"""
    <div id={@dismissable_id} class={[@dismissable_id && "hidden"]}>
      <div class={["rounded-md p-5 relative", @theme.bg, @class]} {@rest}>
        <button
          :if={@dismissable_id}
          class={"absolute right-0 top-0 m-2 #{@theme.title_text}"}
          onclick={"localStorage['notice_dismissed__#{@dismissable_id}'] = 'true'; document.getElementById('#{@dismissable_id}').classList.add('hidden')"}
        >
          <Heroicons.x_mark class="h-4 w-4 hover:stroke-2" />
        </button>
        <div class={[
          "flex gap-3",
          @actions != [] && "items-start flex-col md:items-center md:flex-row"
        ]}>
          <div class="flex gap-x-3 flex-1">
            <div :if={@show_icon && @title} class="shrink-0 mt-px">
              <%= if @icon != [] do %>
                {render_slot(@icon)}
              <% else %>
                <.exclamation_triangle_icon class={"size-4.5 #{@theme.icon}"} />
              <% end %>
            </div>
            <div class="flex-1 flex flex-col gap-y-1.5">
              <h3 :if={@title} class={"font-medium #{@theme.title_text}"}>
                {@title}
              </h3>
              <div class={"#{@theme.body_text}"}>
                <p class="text-pretty">
                  {render_slot(@inner_block)}
                </p>
              </div>
            </div>
          </div>
          <div :if={@actions != []} class="shrink-0 flex gap-2">
            {render_slot(@actions)}
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
  attr(:rest, :global, include: ~w(patch))
  attr(:method, :string, default: "get")
  slot(:inner_block)

  def styled_link(assigns) do
    ~H"""
    <.unstyled_link
      new_tab={@new_tab}
      href={@href}
      method={@method}
      class={"text-indigo-600 hover:text-indigo-700 dark:text-indigo-500 dark:hover:text-indigo-400 transition-colors duration-150 " <> @class}
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
          "origin-top-right absolute z-50 right-0 mt-2 p-1.5 w-max rounded-md shadow-lg overflow-hidden bg-white dark:bg-gray-800 ring-1 ring-black/5 focus:outline-none",
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

  @base_class "block rounded-md text-sm/6 text-gray-900 ui-disabled:text-gray-500 dark:text-gray-100 dark:ui-disabled:text-gray-400 px-3 py-1.5"
  @clickable_class "hover:bg-gray-100 dark:hover:bg-gray-700/80"
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
  attr(:class, :string, default: "")
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
          "inline-flex items-center gap-x-1",
          @class
        ]}
        href={@href}
        target="_blank"
        rel="noopener noreferrer"
        {@extra}
        {@rest}
      >
        {render_slot(@inner_block)}
        <.external_link_icon class={[@icon_class]} />
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
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4">
      </circle>
      <path
        class="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      >
      </path>
    </svg>
    """
  end

  attr :id, :string, required: true
  attr :js_active_var, :string, default: nil
  attr :checked, :boolean, default: nil
  attr :id_suffix, :string, default: ""
  attr :disabled, :boolean, default: false

  attr(:rest, :global)

  @doc """
   Renders toggle input.

   Can be used in two modes:

   1. Alpine JS mode: Pass `:js_active_var` to control toggle state via Alpine JS.
      Set this outside this component with `x-data="{ <variable name>: <initial state> }"`.

   2. Server-side mode: Pass `:checked` boolean and `phx-click` event handler.

   ### Examples - Alpine JS mode
   ```
    <div x-data="{ showGoals: false }>
      <.toggle_switch id="show_goals" js_active_var="showGoals" />
    </div>
   ```

   ### Examples - Server-side mode
   ```
    <.toggle_switch id="my_toggle" checked={@my_toggle} phx-click="toggle-my-setting" phx-target={@myself} />
   ```
  """
  def toggle_switch(assigns) do
    server_mode? = not is_nil(assigns.checked)
    assigns = assign(assigns, :server_mode?, server_mode?)

    ~H"""
    <button
      id={"#{@id}-#{@id_suffix}"}
      class={["h-6", if(@disabled, do: "cursor-not-allowed", else: "cursor-pointer")]}
      aria-labelledby={@id}
      role="switch"
      type="button"
      x-on:click={if(!@server_mode? && @js_active_var, do: "#{@js_active_var} = !#{@js_active_var}")}
      x-bind:aria-checked={if(!@server_mode? && @js_active_var, do: @js_active_var)}
      aria-checked={if(@server_mode?, do: to_string(@checked))}
      disabled={@disabled}
      {@rest}
    >
      <span
        :if={@server_mode?}
        class={[
          "relative inline-flex h-6 w-11 shrink-0 rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-hidden focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2",
          if(@checked, do: "bg-indigo-600", else: "dark:bg-gray-600 bg-gray-200"),
          if(@disabled, do: "opacity-50")
        ]}
      >
        <span
          aria-hidden="true"
          class={[
            "pointer-events-none inline-block size-5 transform rounded-full bg-white shadow-sm ring-0 transition duration-200 ease-in-out",
            if(@checked, do: "dark:bg-white translate-x-5", else: "dark:bg-white translate-x-0")
          ]}
        />
      </span>
      <span
        :if={!@server_mode?}
        class={[
          "relative inline-flex h-6 w-11 shrink-0 rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-hidden focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2",
          if(@disabled, do: "opacity-50")
        ]}
        x-bind:class={"#{@js_active_var} ? 'bg-indigo-600' : 'dark:bg-gray-600 bg-gray-200'"}
      >
        <span
          aria-hidden="true"
          class="pointer-events-none inline-block size-5 transform rounded-full bg-white shadow-sm ring-0 transition duration-200 ease-in-out"
          x-bind:class={"#{@js_active_var} ? 'dark:bg-white translate-x-5' : 'dark:bg-white translate-x-0'"}
        />
      </span>
    </button>
    """
  end

  attr :id, :string, required: true
  attr :js_active_var, :string, required: true
  attr :id_suffix, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :label, :string, required: true
  attr :help_text, :string, default: nil
  attr :show_help_text_only_when_active?, :boolean, default: false
  attr :mt?, :boolean, default: true

  attr(:rest, :global)

  @doc """
   Renders toggle input with a label. Clicking the label also toggles the toggle.
   Needs `:js_active_var` that controls toggle state.
   Set this outside this component with `x-data="{ <variable name>: <initial state> }"`
   Can be configured to always show a description of the field / help text `:help_text`,
   or only show the help text when the toggle is activated `:show_help_text_only_when_active?`.
  """
  def toggle_field(assigns) do
    ~H"""
    <div class={["flex items-start justify-between gap-5 w-full", @mt? && "mt-6"]}>
      <div class="flex-1">
        <span
          x-on:click={"#{@js_active_var} = !#{@js_active_var}"}
          class="text-sm font-medium text-gray-900 dark:text-gray-100 cursor-pointer"
        >
          {@label}
        </span>
        <p
          :if={@help_text}
          class="text-gray-500 dark:text-gray-400 text-sm text-pretty"
          x-show={if @show_help_text_only_when_active?, do: @js_active_var, else: "true"}
          x-cloak={@show_help_text_only_when_active?}
        >
          {@help_text}
        </p>
      </div>
      <PlausibleWeb.Components.Generic.toggle_switch
        id={@id}
        id_suffix={@id_suffix}
        js_active_var={@js_active_var}
        disabled={@disabled}
        {@rest}
      />
    </div>
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
  slot :subtitle, required: false
  attr :feature_mod, :atom, default: nil
  attr :feature_toggle?, :boolean, default: false
  attr :current_team, :any, default: nil
  attr :current_user, :any, default: nil
  attr :site, :any, default: nil
  attr :conn, :any, default: nil
  attr :show_content?, :boolean, default: true

  def tile(assigns) do
    ~H"""
    <div data-test-id="settings-tile" class="shadow-sm bg-white dark:bg-gray-900 rounded-md mb-6">
      <header class="relative py-4 px-6">
        <.title>
          {render_slot(@title)}

          <.docs_info :if={@docs} slug={@docs} class="absolute top-4 right-4 z-1" />
        </.title>
        <div :if={@subtitle != []} class="text-sm mt-px text-gray-500 dark:text-gray-400 leading-5">
          {render_slot(@subtitle)}
        </div>

        <.live_component
          :if={@feature_toggle?}
          module={PlausibleWeb.Components.Site.Feature.ToggleLive}
          id={"feature-toggle-#{@site.id}-#{@feature_mod}"}
          site={@site}
          feature_mod={@feature_mod}
          current_user={@current_user}
        />
      </header>
      <div class={["border-b dark:border-gray-700 mx-6", if(not @show_content?, do: "hidden")]}></div>
      <div class={["relative", if(not @show_content?, do: "hidden")]}>
        <%= if @feature_mod do %>
          <PlausibleWeb.Components.Billing.feature_gate
            locked?={@feature_mod.check_availability(@current_team) != :ok}
            current_user={@current_user}
            current_team={@current_team}
            site={@site}
          >
            <div class="p-4 sm:p-6">
              {render_slot(@inner_block)}
            </div>
          </PlausibleWeb.Components.Billing.feature_gate>
        <% else %>
          <div class="p-4 sm:p-6">
            {render_slot(@inner_block)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:sticky?, :boolean, default: true)
  attr(:enabled?, :boolean, default: true)
  attr(:centered?, :boolean, default: false)
  attr(:testid, :string, default: nil)
  slot(:inner_block, required: true)
  slot(:tooltip_content, required: true)

  def tooltip(assigns) do
    wrapper_data =
      if assigns[:sticky?], do: "{sticky: false, hovered: false}", else: "{hovered: false}"

    show_inner = if assigns[:sticky?], do: "hovered || sticky", else: "hovered"

    base_classes = [
      "absolute",
      "pb-2",
      "top-0",
      "-translate-y-full",
      "z-[1000]",
      "sm:max-w-64",
      "w-max"
    ]

    tooltip_position_classes =
      if assigns.centered? do
        base_classes ++ ["left-1/2", "-translate-x-1/2"]
      else
        base_classes
      end

    assigns =
      assign(assigns,
        wrapper_data: wrapper_data,
        show_inner: show_inner,
        tooltip_position_classes: tooltip_position_classes
      )

    if assigns.enabled? do
      ~H"""
      <div
        x-data={@wrapper_data}
        x-on:mouseenter="hovered = true"
        x-on:mouseleave="hovered = false"
        class={["w-max relative z-[1000]"]}
      >
        <div
          x-cloak
          x-show={@show_inner}
          class={@tooltip_position_classes}
          data-testid={@testid}
          x-transition:enter="transition ease-out duration-200"
          x-transition:enter-start="opacity-0"
          x-transition:enter-end="opacity-100"
          x-transition:leave="transition ease-in duration-150"
          x-transition:leave-start="opacity-100"
          x-transition:leave-end="opacity-0"
        >
          <div class="bg-gray-800 text-white rounded-sm px-2.5 py-1.5 text-xs font-medium whitespace-normal">
            {render_slot(@tooltip_content)}
          </div>
        </div>
        <div x-on:click="sticky = true; hovered = true" x-on:click.outside="sticky = false">
          {render_slot(@inner_block)}
        </div>
      </div>
      """
    else
      ~H"{render_slot(@inner_block)}"
    end
  end

  slot :inner_block, required: true

  def accordion_menu(assigns) do
    ~H"""
    <dl class="divide-y divide-gray-200 dark:divide-gray-700">
      {render_slot(@inner_block)}
    </dl>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :open_by_default, :boolean, default: false
  attr :title_class, :string, default: ""
  slot :inner_block, required: true

  def accordion_item(assigns) do
    ~H"""
    <div x-data={"{ open: #{@open_by_default}}"} class="py-4">
      <dt>
        <button
          type="button"
          class={"flex w-full items-start justify-between text-left #{@title_class}"}
          @click="open = !open"
        >
          <span class="text-base font-semibold">{@title}</span>
          <span class="ml-6 flex h-6 items-center">
            <svg
              x-show="!open"
              class="size-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v12m6-6H6" />
            </svg>
            <svg
              x-show="open"
              class="size-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M18 12H6" />
            </svg>
          </span>
        </button>
      </dt>
      <dd x-show="open" id={@id} class="mt-2 pr-12 text-sm">
        {render_slot(@inner_block)}
      </dd>
    </div>
    """
  end

  attr(:rest, :global, include: ~w(fill stroke stroke-width class))
  attr(:name, :atom, required: true)
  attr(:outline, :boolean, default: true)
  attr(:solid, :boolean, default: false)
  attr(:mini, :boolean, default: false)

  def dynamic_icon(assigns) do
    case assigns.name do
      :tag ->
        PlausibleWeb.Components.Icons.tag_icon(%{class: assigns.rest[:class]})

      :subscription ->
        PlausibleWeb.Components.Icons.subscription_icon(%{class: assigns.rest[:class]})

      :api_keys ->
        PlausibleWeb.Components.Icons.key_icon(%{class: assigns.rest[:class]})

      icon_name ->
        apply(Heroicons, icon_name, [assigns])
    end
  end

  attr(:width, :integer, default: 100)
  attr(:height, :integer, default: 100)
  attr(:id, :string, default: "shuttle")

  defp icon_class(link_assigns) do
    classes = List.wrap(link_assigns[:class]) |> Enum.join(" ")

    if String.contains?(classes, "text-sm") or
         String.contains?(classes, "text-xs") do
      ["size-3"]
    else
      ["size-4"]
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
  attr :padding?, :boolean, default: true
  attr :rest, :global

  def focus_box(assigns) do
    ~H"""
    <div
      class="bg-white w-full max-w-lg mx-auto dark:bg-gray-900 text-gray-900 dark:text-gray-100 shadow-md rounded-md mt-12"
      {@rest}
    >
      <div class={if(@padding?, do: "p-8")}>
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
        <div class="p-8 text-sm">
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
    <table
      :if={not Enum.empty?(@rows)}
      class={[
        "[&:not(:has(thead))>tbody>tr:first-child>td]:pt-0 [&>tbody>tr:last-child>td]:pb-0",
        @width
      ]}
      {@rest}
    >
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
  attr :class, :string, default: ""
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
      class={
        [
          @height,
          "text-sm px-3 md:px-6 py-3 md:py-4 first:pl-0 last:pr-0 whitespace-nowrap",
          # allow tooltips overflow cells vertically
          "overflow-visible",
          @truncate && "truncate",
          @max_width,
          @actions && "flex text-right justify-end",
          @hide_on_mobile && "hidden md:table-cell",
          @class
        ]
      }
      {@rest}
    >
      <div :if={@actions} class="flex gap-1">
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
        "px-6 first:pl-0 last:pr-0 py-3 text-left text-sm font-semibold"
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
    <div class="my-2 flex items-center">
      <button
        type="submit"
        class={[
          "relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full transition-colors ease-in-out duration-200",
          if(@set_to, do: "bg-indigo-600", else: "bg-gray-200 dark:bg-gray-600"),
          if(@disabled?, do: "cursor-not-allowed")
        ]}
        disabled={@disabled?}
      >
        <span
          aria-hidden="true"
          class={[
            "inline-block size-5 rounded-full bg-white shadow transform transition ease-in-out duration-200",
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

  attr :href, :string, required: false
  attr :icon_name, :atom, required: false
  attr :theme, :string, default: "default"
  attr :class, :string, default: ""
  attr :icon_class, :string, default: ""
  attr :size, :string, default: "4"
  attr :rest, :global, include: ~w(method disabled)

  slot :inner_block, required: false

  def icon_button(assigns) do
    icon_source =
      case {assigns.inner_block, assigns[:icon_name]} do
        {[], nil} ->
          raise ArgumentError,
                "Either `icon_name` attribute or icon inner block must be provided"

        {[_ | _], icon_name} when not is_nil(icon_name) ->
          raise ArgumentError, "Only one of `icon_name` and icon inner block must be provided"

        {[_ | _], nil} ->
          :inner_block

        {[], icon_name} when not is_nil(icon_name) ->
          :icon_name
      end

    text =
      case assigns.theme do
        "default" ->
          %{
            light: "text-indigo-700",
            light_hover: "text-indigo-600",
            dark: "text-indigo-500",
            dark_hover: "text-indigo-400"
          }

        "danger" ->
          %{
            light: "text-red-700",
            light_hover: "text-red-500",
            dark: "text-red-500",
            dark_hover: "text-red-400"
          }

        _ ->
          raise ArgumentError, "Invalid `theme` provided"
      end

    button_class = [
      "group/button",
      "w-fit h-fit",
      "p-2",
      "hover:bg-gray-100",
      "dark:hover:bg-gray-800",
      "rounded-md",
      "transition-colors",
      "duration-150",
      assigns.class
    ]

    icon_class = [
      "size-#{assigns.size}",
      text.light,
      "group-hover/button:" <> text.light_hover,
      "dark:" <> text.dark,
      "dark:group-hover/button:" <> text.dark_hover,
      "transition-colors",
      "duration-150",
      "group-disabled/button:opacity-50",
      assigns.icon_class
    ]

    assigns =
      assigns
      |> assign(:icon_source, icon_source)
      |> assign(:button_class, button_class)
      |> assign(:icon_class, icon_class)

    if assigns[:href] do
      ~H"""
      <.unstyled_link href={@href} class={@button_class} {@rest}>
        <span :if={@icon_source == :inner_block}>
          {render_slot(@inner_block, @icon_class)}
        </span>
        <.dynamic_icon
          :if={@icon_source == :icon_name}
          name={@icon_name}
          class={@icon_class}
        />
      </.unstyled_link>
      """
    else
      ~H"""
      <button class={@button_class} {@rest}>
        <span :if={@icon_source == :inner_block}>
          {render_slot(@inner_block, @icon_class)}
        </span>
        <.dynamic_icon
          :if={@icon_source == :icon_name}
          name={@icon_name}
          class={@icon_class}
        />
      </button>
      """
    end
  end

  attr :href, :string, default: nil
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(method disabled)

  def edit_button(assigns) do
    ~H"""
    <.icon_button :let={icon_class} href={@href} class={@class} {@rest}>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        class={icon_class}
      >
        <path
          stroke="currentColor"
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="1.5"
          d="m13.25 6.25 2.836-2.836a2 2 0 0 1 2.828 0l1.672 1.672a2 2 0 0 1 0 2.828L17.75 10.75m-4.5-4.5-9.914 9.914a2 2 0 0 0-.586 1.415v3.671h3.672a2 2 0 0 0 1.414-.586l9.914-9.914m-4.5-4.5 4.5 4.5"
        />
      </svg>
    </.icon_button>
    """
  end

  attr :href, :string, default: nil
  attr :class, :string, default: ""
  attr :icon, :atom, default: :trash
  attr :rest, :global, include: ~w(method disabled)

  def delete_button(assigns) do
    ~H"""
    <.icon_button
      icon_name={@icon}
      theme="danger"
      class={@class}
      href={@href}
      {@rest}
    />
    """
  end

  attr :filter_text, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :filtering_enabled?, :boolean, default: true
  slot :inner_block, required: false

  def filter_bar(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-2" x-data>
      <div :if={@filtering_enabled?} class="relative rounded-md flex flex-grow-1 w-full">
        <form
          id="filter-form"
          phx-change="filter"
          phx-submit="filter"
          class="flex items-center w-full"
        >
          <div class="text-gray-800 inline-flex items-center w-full">
            <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
              <Heroicons.magnifying_glass class="feather mr-1 dark:text-gray-300" />
            </div>
            <input
              type="text"
              name="filter-text"
              id="filter-text"
              class="w-full max-w-80 pl-8 text-sm dark:bg-gray-750 dark:text-gray-300 focus:ring-indigo-500 focus:border-indigo-500 block border-gray-300 dark:border-gray-750 rounded-md dark:placeholder:text-gray-400 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500"
              placeholder="Press / to search"
              x-ref="filter_text"
              phx-debounce={200}
              autocomoplete="off"
              x-on:keydown.slash.window="if (['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName) || document.activeElement.isContentEditable) return; $refs.filter_text.focus(); $refs.filter_text.select();"
              x-on:keydown.escape="$refs.filter_text.blur(); $refs.reset_filter?.dispatchEvent(new Event('click', {bubbles: true, cancelable: true}));"
              value={@filter_text}
              x-on:focus={"$refs.filter_text.placeholder = '#{@placeholder}';"}
              x-on:blur="$refs.filter_text.placeholder = 'Press / to search';"
            />

            <Heroicons.backspace
              :if={String.trim(@filter_text) != ""}
              class="feather ml-2 cursor-pointer hover:text-red-500 dark:text-gray-300 dark:hover:text-red-500"
              phx-click="reset-filter-text"
              id="reset-filter"
              x-ref="reset_filter"
            />
          </div>
        </form>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot :inner_block, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def h2(assigns) do
    ~H"""
    <h2 class={[@class || "font-semibold leading-6 text-gray-900 dark:text-gray-100"]} {@rest}>
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

  alias Phoenix.LiveView.JS

  slot :inner_block, required: true

  def disclosure(assigns) do
    ~H"""
    <div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot :inner_block, required: true
  attr :class, :any, default: nil

  def disclosure_button(assigns) do
    ~H"""
    <button
      type="button"
      id="disclosure-button"
      data-open="false"
      phx-click={
        JS.toggle(to: "#disclosure-panel")
        |> JS.toggle_attribute({"data-open", "true", "false"}, to: "#disclosure-button")
      }
      class={@class}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  slot :inner_block, required: true

  def disclosure_panel(assigns) do
    ~H"""
    <div id="disclosure-panel" style="display: none;">
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot :inner_block, required: true

  def highlighted(assigns) do
    ~H"""
    <span class="font-medium text-indigo-600 dark:text-gray-100">
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr(:class, :string, default: "")
  attr(:color, :atom, default: :gray, values: [:gray, :indigo, :yellow, :green, :red])
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def pill(assigns) do
    assigns = assign(assigns, :color_classes, get_pill_color_classes(assigns.color))

    ~H"""
    <span
      class={[
        "inline-flex items-center text-xs font-medium py-[3px] px-[7px] rounded-md",
        @color_classes,
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp get_pill_color_classes(:gray) do
    "bg-gray-100 text-gray-800 dark:bg-gray-750 dark:text-gray-200"
  end

  defp get_pill_color_classes(:indigo) do
    "bg-indigo-100/60 text-indigo-600 dark:bg-indigo-900/50 dark:text-indigo-300"
  end

  defp get_pill_color_classes(:yellow) do
    "bg-yellow-100/80 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300"
  end

  defp get_pill_color_classes(:green) do
    "bg-green-100/70 text-green-800 dark:bg-green-900/40 dark:text-green-300"
  end

  defp get_pill_color_classes(:red) do
    "bg-red-100/60 text-red-700 dark:bg-red-800/40 dark:text-red-300"
  end
end
