defmodule PlausibleWeb.Components.Layout do
  @moduledoc false

  use Phoenix.Component

  def theme_script(assigns) do
    ~H"""
    <script>
      (function(){
        var userPref = '<%= current_theme(assigns[:current_user]) %>';
        function reapplyTheme() {
          var darkMediaPref = window.matchMedia('(prefers-color-scheme: dark)').matches;
          var htmlRef = document.querySelector('html');
          var hcaptchaRefs = Array.from(document.getElementsByClassName('h-captcha'));

          var isDark = userPref === 'dark' || (userPref === 'system' && darkMediaPref);

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

  defp current_theme(nil), do: "system"
  defp current_theme(user), do: user.theme
end
