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

  defp theme_preference(%{theme: theme}) when not is_nil(theme), do: theme

  defp theme_preference(%{current_user: %Plausible.Auth.User{theme: theme}})
       when not is_nil(theme) do
    theme
  end

  defp theme_preference(_assigns), do: "system"

  defdelegate logo_path(path), to: PlausibleWeb.LayoutView
end
