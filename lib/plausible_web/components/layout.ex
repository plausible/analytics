defmodule PlausibleWeb.Components.Layout do
  @moduledoc false

  use Phoenix.Component

  alias PlausibleWeb.Components.Icons

  attr :class, :string, default: "w-24 sm:w-28"

  def logo(assigns) do
    ~H"""
    <img
      src={logo_url("logo_dark.svg")}
      class={[@class, "hidden dark:inline"]}
      alt="Plausible logo"
      loading="lazy"
    />
    <img
      src={logo_url("logo_light.svg")}
      class={[@class, "inline dark:hidden"]}
      alt="Plausible logo"
      loading="lazy"
    />
    """
  end

  defp logo_url(filename),
    do: PlausibleWeb.Router.Helpers.static_path(PlausibleWeb.Endpoint, logo_path(filename))

  attr :class, :string, default: "h-5"

  def logo_mark(assigns) do
    ~H"""
    <img
      src={PlausibleWeb.Router.Helpers.static_path(PlausibleWeb.Endpoint, "/images/logo_mark.svg")}
      class={["w-auto", @class]}
      alt="Plausible"
    />
    """
  end

  attr :id, :string, required: true
  attr :align, :atom, default: :left, values: [:left, :right]
  attr :width, :string, default: "w-40"
  attr :class, :string, default: nil

  slot :trigger, required: true
  slot :menu, required: true

  def nav_dropdown(assigns) do
    ~H"""
    <div
      id={@id}
      x-data="dropdown"
      x-on:keydown.escape.prevent.stop="close($refs.button)"
      class={["relative flex min-w-0 items-center", @class]}
    >
      {render_slot(List.first(@trigger))}
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
          "absolute top-full z-50 flex flex-col gap-y-0.5 mt-1.5 p-1.5 rounded-lg bg-white dark:bg-gray-800 shadow-lg",
          @align == :left && "origin-top-left left-0",
          @align == :right && "origin-top-right right-0",
          @width
        ]}
      >
        {render_slot(List.first(@menu))}
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :href, :string, required: true
  attr :menu_label, :string, required: true
  attr :menu_width, :string, default: "w-72"

  slot :icon
  slot :menu, required: true

  def nav_chip(assigns) do
    ~H"""
    <.nav_dropdown id={@id} width={@menu_width} class="shrink">
      <:trigger>
        <div
          class="group/split-button flex min-w-0 items-center gap-x-px rounded-md"
          x-bind:class="open && 'bg-gray-100 dark:bg-gray-800'"
        >
          <.link
            href={@href}
            title={@label}
            class="flex min-w-0 items-center gap-x-1.5 rounded-l-md px-1.5 py-1 text-sm font-medium text-gray-900 dark:text-gray-100 group-hover/split-button:bg-gray-150 hover:bg-gray-200 dark:group-hover/split-button:bg-gray-800 dark:hover:bg-gray-800"
          >
            {render_slot(@icon)}
            <span class="truncate">{@label}</span>
          </.link>
          <button
            x-ref="button"
            x-on:click="toggle()"
            type="button"
            aria-label={@menu_label}
            class="shrink-0 rounded-r-md h-7 px-1.5 group-hover/split-button:bg-gray-150 hover:bg-gray-200 dark:group-hover/split-button:bg-gray-800 dark:hover:bg-gray-800"
          >
            <Heroicons.chevron_up_down
              mini
              class="size-3.5 text-gray-600 dark:text-gray-400"
            />
          </button>
        </div>
      </:trigger>
      <:menu>
        {render_slot(@menu)}
      </:menu>
    </.nav_dropdown>
    """
  end

  attr :label, :string, required: true

  def nav_page_label(assigns) do
    ~H"""
    <span
      id="nav-page"
      class="truncate px-1.5 py-1 text-sm font-medium text-gray-900 dark:text-gray-100"
    >
      {@label}
    </span>
    """
  end

  def nav_separator(assigns) do
    ~H"""
    <span
      class="shrink-0 select-none px-1 text-sm text-gray-300 dark:text-gray-600"
      aria-hidden="true"
    >
      /
    </span>
    """
  end

  slot :inner_block, required: true

  def nav_menu_label(assigns) do
    ~H"""
    <div class="px-2.5 py-2 text-xs font-semibold uppercase text-gray-500 dark:text-gray-400">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :href, :string, required: true
  attr :selected, :boolean, default: false
  attr :new_tab, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(method)

  slot :icon
  slot :trailing
  slot :inner_block, required: true

  def nav_menu_item(assigns) do
    ~H"""
    <a
      href={@href}
      target={@new_tab && "_blank"}
      rel={@new_tab && "noopener noreferrer"}
      x-on:click="close()"
      class={[
        "flex w-full min-w-0 items-center gap-x-2 rounded-md p-2.5 text-sm text-gray-900 dark:text-gray-100",
        !@selected && "hover:bg-gray-100 dark:hover:bg-gray-700/80",
        @selected && "bg-gray-100 text-gray-900 dark:bg-gray-700/80 dark:text-gray-100",
        @class
      ]}
      {@rest}
    >
      {render_slot(@icon)}
      <div class="min-w-0 flex-1">
        {render_slot(@inner_block)}
      </div>
      {render_slot(@trailing)}
      <Icons.external_link_icon
        :if={@new_tab}
        class="size-3.5 shrink-0 text-gray-400 dark:text-gray-500 [&_path]:stroke-2"
      />
    </a>
    """
  end

  def nav_menu_divider(assigns) do
    ~H"""
    <div class="my-1 h-px bg-gray-200 dark:bg-gray-700" role="separator"></div>
    """
  end

  slot :inner_block, required: true

  def nav_keybind_hint(assigns) do
    ~H"""
    <span class="shrink-0 rounded bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 px-1.5 font-medium text-xs text-gray-400">
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  An `img` cannot see the `dark` class, so the plug is told the UI mode in the
  URL and both variants are drawn for CSS to choose between.
  """
  attr :domain, :string, required: true
  attr :class, :string, default: "size-5"

  def nav_favicon(assigns) do
    assigns =
      assign(assigns,
        light_src: favicon_src(assigns.domain, "light"),
        dark_src: favicon_src(assigns.domain, "dark")
      )

    ~H"""
    <img
      src={@light_src}
      alt=""
      aria-hidden="true"
      referrerpolicy="no-referrer"
      class={["shrink-0 rounded-md dark:hidden", @class]}
    />
    <img
      src={@dark_src}
      alt=""
      aria-hidden="true"
      referrerpolicy="no-referrer"
      class={["shrink-0 rounded-md hidden dark:block", @class]}
    />
    """
  end

  defp favicon_src(domain, ui_mode),
    do: "/favicon/sources/#{URI.encode_www_form(domain)}?placeholder=site&ui-mode=#{ui_mode}"

  @doc """
  The same drawing as `priv/site_favicon_placeholder.svg` in indigo, so the
  geometry of the two must change together.
  """
  attr :class, :string, default: "size-5"

  def nav_consolidated_view_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 20 20"
      aria-hidden="true"
      class={["shrink-0 text-white", @class]}
    >
      <rect width="20" height="20" rx="5" class="fill-indigo-600" />
      <rect
        x=".5"
        y=".5"
        width="19"
        height="19"
        rx="4.5"
        fill="none"
        stroke-width="1.5"
        class="stroke-white/15"
      />
      <g
        transform="translate(3 3) scale(.5833)"
        fill="none"
        stroke="currentColor"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
      >
        <path d="M22 12H2M12 22c5.714-5.442 5.714-14.558 0-20M12 22C6.286 16.558 6.286 7.442 12 2" />
        <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z" />
      </g>
    </svg>
    """
  end

  attr :user, :any, required: true
  attr :class, :string, default: "size-8 text-sm"

  def nav_avatar(assigns) do
    ~H"""
    <span class={[
      "inline-flex shrink-0 items-center justify-center rounded-full bg-indigo-100 font-semibold uppercase text-indigo-600 tracking-wide dark:bg-indigo-500/25 dark:text-indigo-200",
      @class
    ]}>
      {initials(@user.name)}
    </span>
    """
  end

  defp initials(name) do
    name
    |> to_string()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.first/1)
    |> case do
      [] -> "?"
      [single] -> single
      letters -> [List.first(letters), List.last(letters)]
    end
    |> to_string()
    |> String.upcase()
  end

  def favicon(assigns) do
    ~H"""
    <link
      rel="apple-touch-icon"
      sizes="180x180"
      href={PlausibleWeb.Router.Helpers.static_path(@conn, logo_path("apple-touch-icon.png"))}
    />
    <link
      rel="icon"
      type="image/png"
      sizes="32x32"
      href={PlausibleWeb.Router.Helpers.static_path(@conn, logo_path("favicon-32x32.png"))}
    />
    <link
      rel="icon"
      type="image/png"
      sizes="16x16"
      href={PlausibleWeb.Router.Helpers.static_path(@conn, logo_path("favicon-16x16.png"))}
    />
    """
  end

  def theme_script(assigns) do
    ~H"""
    <script blocking="rendering">
      (function(){
        var themePref = '<%= theme_preference(assigns) %>';
        function reapplyTheme() {
          var darkMediaPref = window.matchMedia('(prefers-color-scheme: dark)').matches;
          var htmlRef = document.querySelector('html');

          var isDark = themePref === 'dark' || (themePref === 'system' && darkMediaPref);

          if (isDark) {
              htmlRef.classList.add('dark')
          } else {
              htmlRef.classList.remove('dark');
          }
        }

        reapplyTheme();
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', reapplyTheme);
      })()
    </script>
    """
  end

  attr(:selected_fn, :any, required: true)
  attr(:prefix, :string, default: "")
  attr(:options, :list, required: true)

  def settings_sidebar(assigns) do
    ~H"""
    <div class="flex flex-col gap-0.5 -ml-2" data-testid="settings-sidebar">
      <.settings_top_tab
        :for={%{key: key, value: value, icon: icon} = opts <- @options}
        selected_fn={@selected_fn}
        prefix={@prefix}
        icon={icon}
        text={key}
        badge={opts[:badge]}
        value={value}
      />
    </div>
    """
  end

  attr(:selected_fn, :any)
  attr(:prefix, :string, default: "")
  attr(:icon, :any, default: nil)
  attr(:text, :string, required: true)
  attr(:badge, :any, default: nil)
  attr(:value, :any, default: nil)

  defp settings_top_tab(assigns) do
    ~H"""
    <%= if is_binary(@value) do %>
      <.settings_tab
        selected_fn={@selected_fn}
        prefix={@prefix}
        icon={@icon}
        text={@text}
        badge={@badge}
        value={@value}
      />
    <% else %>
      <.settings_tab icon={@icon} text={@text} />

      <div class="flex flex-col gap-0.5 ml-7">
        <.settings_tab
          :for={%{key: key, value: value} = opts <- @value}
          selected_fn={@selected_fn}
          prefix={@prefix}
          icon={nil}
          text={key}
          badge={opts[:badge]}
          value={value}
          submenu?={true}
        />
      </div>
    <% end %>
    """
  end

  attr(:selected_fn, :any, default: nil)
  attr(:prefix, :string, default: "")
  attr(:value, :any, default: nil)
  attr(:icon, :any, default: nil)
  attr(:submenu?, :boolean, default: false)
  attr(:text, :string, required: true)
  attr(:badge, :any, default: nil)

  defp settings_tab(assigns) do
    current_tab? = assigns[:selected_fn] != nil and assigns.selected_fn.(assigns[:value])
    assigns = assign(assigns, :current_tab?, current_tab?)

    ~H"""
    <a
      href={@value && @prefix <> "/settings/" <> @value}
      class={[
        "text-sm flex items-center px-2 py-2 leading-5 font-medium rounded-md outline-none focus:outline-none transition ease-in-out duration-150",
        @current_tab? &&
          "text-gray-900 dark:text-gray-100 bg-gray-150 font-semibold dark:bg-gray-850 hover:text-gray-900 dark:hover:text-gray-100 focus:bg-gray-200 dark:focus:bg-gray-800",
        @value && not @current_tab? &&
          "text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-850 focus:text-gray-900 focus:bg-gray-50 dark:focus:text-gray-100 dark:focus:bg-gray-800",
        !@value && "text-gray-600 dark:text-gray-300"
      ]}
    >
      <PlausibleWeb.Components.Generic.dynamic_icon
        :if={not @submenu? && @icon}
        name={@icon}
        class="size-5 mr-2"
      />
      {@text}
      <PlausibleWeb.Components.Generic.pill :if={@badge == :new} color={:indigo} class="ml-2">
        NEW 🔥
      </PlausibleWeb.Components.Generic.pill>
      <Heroicons.chevron_down
        :if={is_nil(@value)}
        class="h-3 w-3 ml-2 text-gray-400 dark:text-gray-500"
      />
    </a>
    """
  end

  defp theme_preference(%{theme: theme}) when not is_nil(theme), do: theme

  defp theme_preference(%{current_user: %Plausible.Auth.User{theme: theme}})
       when not is_nil(theme) do
    theme
  end

  defp theme_preference(_assigns), do: "system"

  defdelegate logo_path(path), to: PlausibleWeb.LayoutView
end
