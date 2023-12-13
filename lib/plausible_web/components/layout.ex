defmodule PlausibleWeb.Components.Layout do
  @moduledoc false

  use Phoenix.Component

  def theme_script(assigns) do
    ~H"""
    <script>
      var userPref = '<%= current_theme(@conn) %>';
      function reapplyTheme() {
       var mediaPref = window.matchMedia('(prefers-color-scheme: dark)').matches;
       var htmlRef = document.querySelector('html');
       var hcaptchaRefs = document.getElementsByClassName('h-captcha');

       var isDark = userPref === 'dark' || (userPref === 'system' && mediaPref)

       if (isDark) {
          htmlRef.classList.add('dark')
        for (let i = 0; i < hcaptchaRefs.length; i++) {
           hcaptchaRefs[i].dataset.theme = "dark";
        }
       } else {
          htmlRef.classList.remove('dark');
          for (let i = 0; i < hcaptchaRefs.length; i++) {
           hcaptchaRefs[i].dataset.theme = "light";
          }
       }
      }

      reapplyTheme();
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', reapplyTheme);
    </script>
    """
  end

  defp current_theme(conn) do
    theme = conn.assigns[:current_user] && conn.assigns[:current_user].theme
    theme || "system"
  end
end
