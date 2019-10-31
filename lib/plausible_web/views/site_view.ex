defmodule PlausibleWeb.SiteView do
  use PlausibleWeb, :view

  def goal_name(%Plausible.Goal{page_path: page_path}) when is_binary(page_path)  do
    "Visit " <> page_path
  end

  def goal_name(%Plausible.Goal{event_name: name}) when is_binary(name) do
    name
  end

  def snippet() do
    """
    <script>
      (function (w,d,s,o,f,js,fjs) {
      w[o] = w[o] || function () { (w[o].q = w[o].q || []).push(arguments) };
      js = d.createElement(s), fjs = d.getElementsByTagName(s)[0];
      js.id = o; js.src = f; js.async = 1; fjs.parentNode.insertBefore(js, fjs);
      }(window, document, 'script', 'plausible', 'https://plausible.io/js/p.js'));

      plausible('page')
    </script>\
    """
  end
end
