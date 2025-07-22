defmodule PlausibleWeb.Components.Layout do
  @moduledoc false

  use Phoenix.Component

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
          var hcaptchaRefs = Array.from(document.getElementsByClassName('h-captcha'));

          var isDark = themePref === 'dark' || (themePref === 'system' && darkMediaPref);

          if (isDark) {
              htmlRef.classList.add('dark')
              hcaptchaRefs.forEach(function(ref) { ref.dataset.theme = "dark"; });
          } else {
              htmlRef.classList.remove('dark');
              hcaptchaRefs.forEach(function(ref) { ref.dataset.theme = "light"; });
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
    <.settings_top_tab
      :for={%{key: key, value: value, icon: icon} = opts <- @options}
      selected_fn={@selected_fn}
      prefix={@prefix}
      icon={icon}
      text={key}
      badge={opts[:badge]}
      value={value}
    />
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

      <div class="ml-6">
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
          "text-gray-900 dark:text-gray-100 bg-gray-100 font-semibold dark:bg-gray-900 hover:text-gray-900 focus:bg-gray-200 dark:focus:bg-gray-800",
        @value && not @current_tab? &&
          "text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-800 focus:text-gray-900 focus:bg-gray-50 dark:focus:text-gray-100 dark:focus:bg-gray-800",
        !@value && "text-gray-600 dark:text-gray-400"
      ]}
    >
      <PlausibleWeb.Components.Generic.dynamic_icon
        :if={not @submenu? && @icon}
        name={@icon}
        class={["h-4 w-4 mr-2", @current_tab? && "stroke-2"]}
      />
      {@text}
      <.settings_badge type={@badge} />
      <Heroicons.chevron_down
        :if={is_nil(@value)}
        class="h-3 w-3 ml-2 text-gray-400 dark:text-gray-500"
      />
    </a>
    """
  end

  defp settings_badge(%{type: :new} = assigns) do
    ~H"""
    <span class="inline-block ml-2 bg-indigo-700 text-gray-100 text-xs p-1 rounded">
      NEW
    </span>
    """
  end

  defp settings_badge(assigns), do: ~H""

  defp theme_preference(%{theme: theme}) when not is_nil(theme), do: theme

  defp theme_preference(%{current_user: %Plausible.Auth.User{theme: theme}})
       when not is_nil(theme) do
    theme
  end

  defp theme_preference(_assigns), do: "system"

  defdelegate logo_path(path), to: PlausibleWeb.LayoutView
end
