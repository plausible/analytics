defmodule PlausibleWeb.Layouts do
  @moduledoc false

  use PlausibleWeb, :component
  use Plausible

  require Plausible.Billing

  alias PlausibleWeb.Components.Billing.Notice
  alias PlausibleWeb.Components.Layout

  embed_templates "layouts/*.html"

  attr :embedded, :boolean, default: false
  attr :header?, :boolean, default: true
  attr :footer?, :boolean, default: true
  attr :global_notices?, :boolean, default: true
  attr :trial_badge?, :boolean, default: true
  attr :load_dashboard_js, :boolean, default: false
  attr :flash, :map, default: %{}
  attr :current_user, :any, default: nil
  attr :current_team, :any, default: nil
  attr :current_team_role, :any, default: nil
  attr :teams, :list, default: []
  attr :my_team, :any, default: nil
  attr :site, :any, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class={["flex flex-col", if(!@embedded, do: "h-full")]}>
      <.flash :if={!@embedded} flash={@flash} />

      <%= if !@embedded && @header? do %>
        <.header
          current_user={@current_user}
          site={@site}
          current_team={@current_team}
          current_team_role={@current_team_role}
          trial_badge?={@trial_badge?}
          teams={@teams}
          my_team={@my_team}
        />

        <.team_notices :if={@global_notices?} current_team={@current_team} />
      <% end %>

      <main class="flex-1 flex flex-col">
        {render_slot(@inner_block)}
      </main>

      <%= if @embedded do %>
        <div data-iframe-height></div>
        <script
          type="text/javascript"
          src={Routes.static_path(PlausibleWeb.Endpoint, "/js/embed.content.js")}
        >
        </script>
      <% end %>
      <.footer :if={@footer?} />
      <script type="text/javascript" src={Routes.static_path(PlausibleWeb.Endpoint, "/js/app.js")}>
      </script>
      <%= if @load_dashboard_js do %>
        <script
          type="text/javascript"
          src={Routes.static_path(PlausibleWeb.Endpoint, "/js/dashboard.js")}
        >
        </script>
      <% end %>
    </div>
    """
  end

  def legacy(assigns) do
    ~H"""
    <.app
      embedded={!!assigns[:embedded]}
      header?={!assigns[:hide_header?]}
      footer?={!assigns[:hide_footer?]}
      global_notices?={!assigns[:disable_global_notices?]}
      trial_badge?={!assigns[:hide_trial_badge?]}
      load_dashboard_js={!!assigns[:load_dashboard_js]}
      flash={assigns[:flash] || %{}}
      current_user={assigns[:current_user]}
      current_team={assigns[:current_team]}
      current_team_role={assigns[:current_team_role]}
      teams={assigns[:teams] || []}
      my_team={assigns[:my_team]}
      site={assigns[:site]}
    >
      {Map.get(assigns, :inner_layout) || @inner_content}
    </.app>
    """
  end
end
