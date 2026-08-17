defmodule PlausibleWeb.Layouts do
  @moduledoc false

  use Phoenix.Component

  alias PlausibleWeb.Router.Helpers, as: Routes

  def legacy(assigns) do
    ~H"""
    <div class={["flex flex-col", if(!assigns[:embedded], do: "h-full")]}>
      <%= if !assigns[:embedded] && assigns[:flash] do %>
        {PlausibleWeb.LayoutView.render("_flash.html", assigns)}
      <% end %>

      <%= if !assigns[:embedded] && !assigns[:hide_header?] do %>
        {PlausibleWeb.LayoutView.render("_header.html", assigns)}

        <%= if !assigns[:disable_global_notices?] do %>
          {PlausibleWeb.LayoutView.render("_notice.html", assigns)}
        <% end %>
      <% end %>

      <main class="flex-1 flex flex-col">
        {Map.get(assigns, :inner_layout) || @inner_content}
      </main>

      <%= if assigns[:embedded] do %>
        <div data-iframe-height></div>
        <script type="text/javascript" src={Routes.static_path(@conn, "/js/embed.content.js")}>
        </script>
      <% end %>
      <%= if !assigns[:hide_footer?] do %>
        {PlausibleWeb.LayoutView.render("_footer.html", assigns)}
      <% end %>
      <script type="text/javascript" src={Routes.static_path(@conn, "/js/app.js")}>
      </script>
      <%= if assigns[:load_dashboard_js] do %>
        <script type="text/javascript" src={Routes.static_path(@conn, "/js/dashboard.js")}>
        </script>
      <% end %>
    </div>
    """
  end
end
