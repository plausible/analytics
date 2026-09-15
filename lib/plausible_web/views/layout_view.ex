defmodule PlausibleWeb.LayoutView do
  use PlausibleWeb, :view
  use Plausible

  alias Plausible.Teams
  alias PlausibleWeb.Components.Layout
  alias PlausibleWeb.Layouts

  require Plausible.Billing

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def websocket_url() do
    PlausibleWeb.Endpoint.websocket_url()
  end

  defmodule JWT do
    use Joken.Config
  end

  def feedback_link(user) do
    token_params = %{
      "id" => user.id,
      "email" => user.email,
      "name" => user.name,
      "imageUrl" => Plausible.Auth.User.profile_img_url(user)
    }

    case JWT.generate_and_sign(token_params) do
      {:ok, token, _claims} ->
        "https://feedback.plausible.io/sso/#{token}?returnUrl=https://feedback.plausible.io"

      _ ->
        "https://feedback.plausible.io"
    end
  end

  def home_dest(current_user) do
    if current_user, do: "/sites", else: "/"
  end

  def logo_path(filename) do
    if ee?() do
      Path.join("/images/ee/", filename)
    else
      Path.join("/images/ce/", filename)
    end
  end

  def site_settings_sidebar(conn) do
    regular_site? = Plausible.Sites.regular?(conn.assigns.site)

    [
      %{key: "General", value: "general", icon: :rocket_launch},
      if regular_site? do
        %{key: "People", value: "people", icon: :users}
      end,
      if regular_site? do
        %{key: "Visibility", value: "visibility", icon: :eye}
      end,
      %{key: "Goals", value: "goals", icon: :check_circle},
      on_ee do
        if regular_site? do
          %{key: "Funnels", value: "funnels", icon: :funnel}
        end
      end,
      %{key: "Custom properties", value: "properties", icon: :tag},
      if regular_site? do
        %{key: "Integrations", value: "integrations", icon: :puzzle_piece}
      end,
      if regular_site? do
        %{key: "Imports & exports", value: "imports-exports", icon: :arrow_down_tray}
      end,
      if regular_site? do
        %{
          key: "Shields",
          icon: :shield_exclamation,
          value: [
            %{key: "IP addresses", value: "shields/ip_addresses"},
            %{key: "Countries", value: "shields/countries"},
            %{key: "Pages", value: "shields/pages"},
            %{key: "Hostnames", value: "shields/hostnames"}
          ]
        }
      end,
      %{key: "Email reports", value: "email-reports", icon: :envelope},
      if regular_site? and conn.assigns[:site_role] in [:owner, :admin] do
        %{key: "Danger zone", value: "danger-zone", icon: :exclamation_triangle}
      end
    ]
    |> Enum.reject(&is_nil/1)
  end

  def account_settings_sidebar(assigns) do
    current_team = assigns.current_team
    current_team_role = assigns.current_team_role

    options = %{
      "Account" =>
        [
          %{key: "Preferences", value: "preferences", icon: :cog_6_tooth},
          %{key: "Security", value: "security", icon: :lock_closed},
          if(ee?() and not Teams.setup?(current_team),
            do: %{key: "Subscription", value: "billing/subscription", icon: :subscription}
          ),
          if(not Teams.setup?(current_team),
            do: %{key: "API keys", value: "api-keys", icon: :api_keys}
          ),
          if(Plausible.Users.type(assigns.current_user) == :standard,
            do: %{key: "Danger zone", value: "danger-zone", icon: :exclamation_triangle}
          )
        ]
        |> Enum.reject(&is_nil/1)
    }

    if Teams.setup?(current_team) do
      Map.put(
        options,
        "Team",
        [
          %{key: "General", value: "team/general", icon: :adjustments_horizontal},
          if(ee?() and current_team_role in Plausible.Billing.allowed_roles(),
            do: %{key: "Subscription", value: "billing/subscription", icon: :subscription}
          ),
          if(current_team_role in [:owner, :billing, :admin, :editor],
            do: %{key: "API keys", value: "api-keys", icon: :api_keys}
          ),
          if(
            ee?() and current_team_role == :owner and
              Plausible.Billing.Feature.SSO.check_availability(current_team) == :ok,
            do: %{
              key: "Single Sign-On",
              icon: :cloud,
              value: [
                %{key: "Configuration", value: "sso/general"},
                %{key: "Sessions", value: "sso/sessions"}
              ]
            }
          ),
          if(
            ee?() and Plausible.Billing.Feature.SSO.check_availability(current_team) != :ok,
            do: %{
              key: "Single Sign-On",
              value: "sso/info",
              icon: :cloud
            }
          ),
          if(current_team_role == :owner,
            do: %{key: "Danger zone", value: "team/delete", icon: :exclamation_triangle}
          )
        ]
        |> Enum.reject(&is_nil/1)
      )
    else
      options
    end
  end

  def nav_page(%{conn: nil}), do: nil

  def nav_page(%{conn: conn}) do
    case conn.path_info do
      ["settings" | _] -> "Settings"
      [_domain, "settings" | _] -> "Site settings"
      _ -> nil
    end
  end

  attr :conn, :any, default: nil
  attr :current_user, :any, required: true
  attr :current_team, :any, default: nil
  attr :current_team_role, :any, default: nil
  attr :teams, :list, default: []
  attr :my_team, :any, default: nil
  attr :site, :any, default: nil
  attr :site_role, :any, default: nil
  attr :nav_sites, :list, default: []
  attr :nav_team_meta, :map, default: %{}

  def breadcrumb(assigns) do
    assigns = assign(assigns, :page, nav_page(assigns))

    ~H"""
    <div class="flex min-w-0 flex-1 items-center gap-x-1">
      <.link
        href={home_dest(@current_user)}
        class="mr-2"
      >
        <Layout.logo_mark />
      </.link>

      <Layout.nav_chip
        id="nav-team"
        label={Teams.name(@current_team)}
        href={Routes.site_path(PlausibleWeb.Endpoint, :index)}
        menu_label="Switch team"
        menu_width="w-72"
      >
        <:menu>
          <.team_menu
            teams={@teams}
            my_team={@my_team}
            current_team={@current_team}
            nav_team_meta={@nav_team_meta}
          />
        </:menu>
      </Layout.nav_chip>

      <%= if @site do %>
        <Layout.nav_separator />
        <Layout.nav_chip
          id="nav-site"
          label={Plausible.Sites.display_name(@site)}
          href={"/#{URI.encode_www_form(@site.domain)}"}
          menu_label="Switch dashboard"
        >
          <:icon>
            <Layout.nav_favicon :if={Plausible.Sites.regular?(@site)} domain={@site.domain} />
            <Layout.nav_consolidated_view_icon :if={not Plausible.Sites.regular?(@site)} />
          </:icon>
          <:menu>
            <.site_menu
              site={@site}
              site_role={@site_role}
              nav_sites={@nav_sites}
              current_team={@current_team}
              current_team_role={@current_team_role}
              current_user={@current_user}
            />
          </:menu>
        </Layout.nav_chip>
      <% end %>

      <%= if @page do %>
        <Layout.nav_separator />
        <Layout.nav_page_label label={@page} />
      <% end %>
    </div>
    """
  end

  attr :teams, :list, required: true
  attr :my_team, :any, default: nil
  attr :current_team, :any, default: nil
  attr :nav_team_meta, :map, default: %{}

  defp team_menu(assigns) do
    rows =
      for team <- switchable_teams(assigns.teams, assigns.my_team, assigns.current_team) do
        %{
          team: team,
          subtitle: team_subtitle(team, assigns.nav_team_meta),
          current?: current_team?(team, assigns.current_team)
        }
      end

    assigns = assign(assigns, :rows, rows)

    ~H"""
    <Layout.nav_menu_label>Switch team</Layout.nav_menu_label>
    <div class="flex flex-col gap-y-0.5 max-h-64 overflow-y-auto">
      <Layout.nav_menu_item
        :for={row <- @rows}
        href={Routes.site_path(PlausibleWeb.Endpoint, :index, __team: row.team.identifier)}
        selected={row.current?}
      >
        <span class="block truncate font-medium text-gray-900 dark:text-gray-100">
          {Teams.name(row.team)}
        </span>
        <span
          :if={row.subtitle}
          class="block truncate text-xs text-gray-500 dark:text-gray-400"
        >
          {row.subtitle}
        </span>
        <:trailing>
          <Heroicons.check
            :if={row.current?}
            class="size-4 shrink-0 stroke-2 text-gray-500 dark:text-gray-400"
          />
        </:trailing>
      </Layout.nav_menu_item>
    </div>

    <Layout.nav_menu_divider />

    <Layout.nav_menu_item
      :if={Teams.setup?(@current_team)}
      href={Routes.settings_path(PlausibleWeb.Endpoint, :team_general)}
    >
      <:icon>
        <Heroicons.cog_6_tooth class={nav_icon_class()} />
      </:icon>
      Settings
    </Layout.nav_menu_item>
    <Layout.nav_menu_item href={Routes.team_setup_path(PlausibleWeb.Endpoint, :setup)}>
      <:icon>
        <Heroicons.plus class={nav_icon_class()} />
      </:icon>
      Create new team
    </Layout.nav_menu_item>
    """
  end

  attr :site, :any, required: true
  attr :site_role, :any, default: nil
  attr :nav_sites, :list, default: []
  attr :current_team, :any, default: nil
  attr :current_team_role, :any, default: nil
  attr :current_user, :any, required: true

  defp site_menu(assigns) do
    {consolidated, regular} = Enum.split_with(assigns.nav_sites, & &1.consolidated)

    assigns =
      assigns
      |> assign(:consolidated, List.first(consolidated))
      |> assign(:regular_sites, Enum.take(regular, 8))

    ~H"""
    <Layout.nav_menu_label>Switch dashboard</Layout.nav_menu_label>

    <Layout.nav_menu_item
      :if={@consolidated}
      href={switch_to_site_url(@site, @consolidated)}
      selected={@consolidated.domain == @site.domain}
    >
      <:icon>
        <Layout.nav_consolidated_view_icon />
      </:icon>
      <span class="block truncate">All sites</span>
      <:trailing>
        <Heroicons.check
          :if={@consolidated.domain == @site.domain}
          class="size-4 shrink-0 stroke-2 text-gray-500 dark:text-gray-400"
        />
        <Layout.nav_keybind_hint>0</Layout.nav_keybind_hint>
      </:trailing>
    </Layout.nav_menu_item>

    <Layout.nav_menu_item
      :for={{site, index} <- Enum.with_index(@regular_sites, 1)}
      href={switch_to_site_url(@site, site)}
      selected={site.domain == @site.domain}
    >
      <:icon>
        <Layout.nav_favicon domain={site.domain} />
      </:icon>
      <span class="block truncate">{site.domain}</span>
      <:trailing>
        <Heroicons.check
          :if={site.domain == @site.domain}
          class="size-4 shrink-0 stroke-2 text-gray-500 dark:text-gray-400"
        />
        <Layout.nav_keybind_hint>{index}</Layout.nav_keybind_hint>
      </:trailing>
    </Layout.nav_menu_item>

    <Layout.nav_menu_divider :if={
      can_see_site_settings?(@site_role) or
        can_add_site?(@current_team, @current_team_role, @current_user)
    } />

    <Layout.nav_menu_item
      :if={can_see_site_settings?(@site_role)}
      href={"/#{URI.encode_www_form(@site.domain)}/settings/general"}
    >
      <:icon>
        <Heroicons.cog_6_tooth class={nav_icon_class()} />
      </:icon>
      Site settings
    </Layout.nav_menu_item>
    <Layout.nav_menu_item
      :if={can_add_site?(@current_team, @current_team_role, @current_user)}
      href={Routes.site_path(PlausibleWeb.Endpoint, :new, %{flow: PlausibleWeb.Flows.provisioning()})}
    >
      <:icon>
        <Heroicons.plus class={nav_icon_class()} />
      </:icon>
      Add website
    </Layout.nav_menu_item>
    """
  end

  def nav_icon_class, do: "size-4.5 shrink-0 text-gray-600 dark:text-gray-400"

  defp current_team?(team, current_team) do
    not is_nil(current_team) and team.id == current_team.id
  end

  defp team_subtitle(team, nav_team_meta) do
    case Map.get(nav_team_meta, team.id) do
      nil -> nil
      %{plan: nil, members: members} -> pluralize_members(members)
      %{plan: plan, members: members} -> "#{plan} · #{pluralize_members(members)}"
    end
  end

  defp pluralize_members(1), do: "1 member"
  defp pluralize_members(count), do: "#{count} members"

  # Mirrors `Plausible.Teams.Memberships.can_add_site?/2` without the extra role
  # lookup, since `AuthPlug` already resolved the current team role.
  defp can_add_site?(current_team, current_team_role, current_user) do
    case {Plausible.Users.type(current_user), current_team_role, current_team} do
      {:sso, :owner, %{setup_complete: false}} -> false
      {_, role, _} when role in [:owner, :admin, :editor] -> true
      _ -> false
    end
  end

  defp can_see_site_settings?(site_role) do
    site_role in [:owner, :admin, :editor, :super_admin]
  end

  # Avoids a full page reload when the current dashboard is picked again.
  defp switch_to_site_url(%{domain: domain}, %{domain: domain}), do: "#"

  defp switch_to_site_url(_current_site, site) do
    url = "/#{URI.encode_www_form(site.domain)}"

    if site.needs_verification do
      "#{url}?verify_installation=true&flow=#{PlausibleWeb.Flows.provisioning()}"
    else
      url
    end
  end

  defp switchable_teams(teams, my_team, current_team) do
    teams = teams || []
    current_included? = current_team && Enum.any?(teams, &(&1.id == current_team.id))
    current_is_my? = current_team && my_team && current_team.id == my_team.id

    teams =
      if current_team && !current_included? && !current_is_my? do
        [current_team | teams]
      else
        teams
      end

    teams =
      if my_team do
        teams ++ [my_team]
      else
        teams ++ [%Teams.Team{identifier: "none", name: Teams.default_name()}]
      end

    selected_id = current_team && current_team.id
    {pinned, others} = Enum.split_with(teams, &(&1.id == selected_id))

    pinned ++ others
  end

  def trial_notification(team) do
    case Teams.trial_days_left(team) do
      days when days > 1 ->
        "#{days} trial days left"

      days when days == 1 ->
        "Trial ends tomorrow"

      days when days == 0 ->
        "Trial ends today"
    end
  end

  def current_tab?(_, nil) do
    false
  end

  def current_tab?(path, tab) when is_binary(path) do
    String.ends_with?(path, tab)
  end

  def current_tab?(conn, tab) do
    full_path = Path.join(conn.path_info)

    one_up =
      conn.path_info
      |> Enum.drop(-1)
      |> Path.join()

    case conn.method do
      :get -> String.ends_with?(full_path, tab)
      _ -> String.ends_with?(full_path, tab) or String.ends_with?(one_up, tab)
    end
  end
end
