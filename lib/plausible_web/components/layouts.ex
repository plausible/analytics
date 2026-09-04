defmodule PlausibleWeb.Layouts do
  @moduledoc false

  use PlausibleWeb, :component
  use Plausible

  require Plausible.Billing

  alias PlausibleWeb.Components.Billing.Notice
  alias PlausibleWeb.Components.Layout

  embed_templates "layouts/*.html"

  attr :header?, :boolean, default: true
  attr :footer?, :boolean, default: true
  attr :global_notices?, :boolean, default: true
  attr :trial_badge?, :boolean, default: true
  attr :embedded?, :boolean, default: false
  attr :load_dashboard_js?, :boolean, default: false
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
    <div class={["flex flex-col", if(!@embedded?, do: "h-full")]}>
      <.flash :if={not @embedded?} flash={@flash} />

      <%= if !@embedded? && @header? do %>
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

      <%= if @embedded? do %>
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
      <%= if @load_dashboard_js? do %>
        <script
          type="text/javascript"
          src={Routes.static_path(PlausibleWeb.Endpoint, "/js/dashboard.js")}
        >
        </script>
      <% end %>
    </div>
    """
  end

  attr :hide_header?, :boolean, default: false
  attr :hide_footer?, :boolean, default: false
  attr :disable_global_notices?, :boolean, default: false
  attr :hide_trial_badge?, :boolean, default: false
  attr :embedded, :boolean, default: false
  attr :load_dashboard_js, :boolean, default: false
  attr :flash, :map, default: %{}
  attr :current_user, :any, default: nil
  attr :current_team, :any, default: nil
  attr :current_team_role, :any, default: nil
  attr :teams, :list, default: []
  attr :my_team, :any, default: nil
  attr :site, :any, default: nil
  slot :inner_block, required: true

  def legacy(assigns) do
    ~H"""
    <.app
      header?={not @hide_header?}
      footer?={not @hide_footer?}
      global_notices?={not @disable_global_notices?}
      trial_badge?={not @hide_trial_badge?}
      embedded?={@embedded}
      load_dashboard_js?={@load_dashboard_js}
      flash={@flash}
      current_user={@current_user}
      current_team={@current_team}
      current_team_role={@current_team_role}
      teams={@teams}
      my_team={@my_team}
      site={@site}
    >
      {render_slot(@inner_block)}
    </.app>
    """
  end

  attr :heading, :string, required: true
  attr :subtitle, :string, default: nil
  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  def auth(assigns) do
    ~H"""
    <.app header?={false} footer?={false} global_notices?={false} flash={@flash}>
      <div class="min-h-screen w-full bg-white dark:bg-gray-900">
        <div class="flex justify-center pt-12 sm:pt-20">
          <a href="/">
            <Layout.logo />
          </a>
        </div>

        <div class="max-w-md mx-auto mt-10 sm:mt-16 px-4 flex flex-col gap-y-2 text-center dark:text-gray-300">
          <h1 class="text-lg sm:text-xl font-semibold">
            {@heading}
          </h1>
          <p :if={@subtitle} class="text-base text-gray-500 dark:text-gray-400 text-pretty">
            {@subtitle}
          </p>
        </div>
        {render_slot(@inner_block)}
      </div>
    </.app>
    """
  end

  attr :current_user, :any, default: nil
  attr :current_step, :string, required: true
  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  def onboarding(assigns) do
    ~H"""
    <.app
      footer?={false}
      global_notices?={false}
      trial_badge?={false}
      current_user={@current_user}
      flash={@flash}
    >
      <div class="flex-1 flex flex-col">
        <div class="flex-1">
          {render_slot(@inner_block)}
        </div>
        <div class="pb-20 flex justify-center">
          <PlausibleWeb.Components.FlowProgress.render
            steps={PlausibleWeb.Flows.onboarding_steps()}
            current_step={@current_step}
          />
        </div>
      </div>
    </.app>
    """
  end
end
