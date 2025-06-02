defmodule PlausibleWeb.LayoutView do
  use PlausibleWeb, :view
  use Plausible

  alias Plausible.Teams
  alias PlausibleWeb.Components.Billing.Notice

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

  def home_dest(conn) do
    if conn.assigns[:current_user] do
      Routes.site_url(PlausibleWeb.Endpoint, :index)
    else
      Routes.page_url(PlausibleWeb.Endpoint, :index)
    end
  end

  def logo_path(filename) do
    if ee?() do
      Path.join("/images/ee/", filename)
    else
      Path.join("/images/ce/", filename)
    end
  end

  def site_settings_sidebar(conn) do
    [
      %{key: "General", value: "general", icon: :rocket_launch},
      %{key: "People", value: "people", icon: :users},
      %{key: "Visibility", value: "visibility", icon: :eye},
      %{key: "Goals", value: "goals", icon: :check_circle},
      on_ee do
        %{key: "Funnels", value: "funnels", icon: :funnel}
      end,
      %{key: "Custom Properties", value: "properties", icon: :document_text},
      %{key: "Integrations", value: "integrations", icon: :arrow_path_rounded_square},
      %{key: "Imports & Exports", value: "imports-exports", icon: :arrows_up_down},
      %{
        key: "Shields",
        icon: :shield_exclamation,
        value: [
          %{key: "IP Addresses", value: "shields/ip_addresses"},
          %{key: "Countries", value: "shields/countries"},
          %{key: "Pages", value: "shields/pages"},
          %{key: "Hostnames", value: "shields/hostnames"}
        ]
      },
      %{key: "Email Reports", value: "email-reports", icon: :envelope},
      if conn.assigns[:site_role] in [:owner, :admin] do
        %{key: "Danger Zone", value: "danger-zone", icon: :exclamation_triangle}
      end
    ]
    |> Enum.reject(&is_nil/1)
  end

  def flat_site_settings_options(conn) do
    conn
    |> site_settings_sidebar()
    |> Enum.map(fn
      %{value: value, key: key} when is_binary(value) ->
        {key, value}

      %{value: submenu_items, key: parent_key} when is_list(submenu_items) ->
        Enum.map(submenu_items, fn submenu_item ->
          {"#{parent_key}: #{submenu_item.key}", submenu_item.value}
        end)
    end)
    |> List.flatten()
  end

  def account_settings_sidebar(conn) do
    current_team = conn.assigns[:current_team]
    current_team_role = conn.assigns[:current_team_role]

    options = %{
      "Account Settings" =>
        [
          %{key: "Preferences", value: "preferences", icon: :cog_6_tooth},
          %{key: "Security", value: "security", icon: :lock_closed},
          if(not Teams.setup?(current_team),
            do: %{key: "Subscription", value: "billing/subscription", icon: :circle_stack}
          ),
          if(not Teams.setup?(current_team),
            do: %{key: "Invoices", value: "billing/invoices", icon: :banknotes}
          ),
          if(not Teams.setup?(current_team),
            do: %{key: "API Keys", value: "api-keys", icon: :key}
          ),
          %{key: "Danger Zone", value: "danger-zone", icon: :exclamation_triangle}
        ]
        |> Enum.reject(&is_nil/1)
    }

    if Teams.setup?(current_team) do
      Map.put(
        options,
        "Team Settings",
        [
          %{key: "General", value: "team/general", icon: :adjustments_horizontal},
          if(current_team_role in [:owner, :billing],
            do: %{key: "Subscription", value: "billing/subscription", icon: :circle_stack}
          ),
          if(current_team_role in [:owner, :billing],
            do: %{key: "Invoices", value: "billing/invoices", icon: :banknotes}
          ),
          if(current_team_role in [:owner, :billing, :admin, :editor],
            do: %{key: "API Keys", value: "api-keys", icon: :key}
          ),
          if(Plausible.sso_enabled?() and current_team_role == :owner,
            do: %{key: "Single Sign-On", value: "sso/general", icon: :cloud}
          ),
          if(current_team_role == :owner,
            do: %{key: "Danger Zone", value: "team/delete", icon: :exclamation_triangle}
          )
        ]
        |> Enum.reject(&is_nil/1)
      )
    else
      options
    end
  end

  attr :conn, :map, required: true
  attr :teams, :list, required: true
  attr :my_team, :any, default: nil
  attr :current_team, :any, default: nil
  attr :more_teams?, :boolean, required: true

  def team_switcher(assigns) do
    teams = assigns[:teams]

    if teams && length(teams) > 0 do
      current_team = assigns[:current_team]
      my_team = assigns[:my_team]
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

      assigns =
        assigns
        |> assign(:teams, teams)
        |> assign(:selected_id, selected_id)

      ~H"""
      <.dropdown_item>
        <div class="text-xs text-gray-500 dark:text-gray-400">Teams</div>
      </.dropdown_item>
      <.dropdown_item
        :for={team <- @teams}
        href={Routes.site_path(@conn, :index, __team: team.identifier)}
      >
        <p
          class={[
            if(team.id == @selected_id,
              do: "border-r-4 border-indigo-400 font-bold",
              else: "font-medium"
            ),
            "truncate text-gray-900 dark:text-gray-100 pr-4"
          ]}
          role="none"
        >
          {Teams.name(team)}
        </p>
      </.dropdown_item>
      <.dropdown_item :if={@more_teams?} href={Routes.auth_path(@conn, :select_team)}>
        Switch to Another Team
      </.dropdown_item>
      """
    else
      ~H""
    end
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

  def grace_period_end(%{grace_period: %{end_date: %Date{} = date}}) do
    case Date.diff(date, Date.utc_today()) do
      0 -> "today"
      1 -> "tomorrow"
      n -> "within #{n} days"
    end
  end

  def grace_period_end(_user), do: "in the following days"

  @doc "http://blog.plataformatec.com.br/2018/05/nested-layouts-with-phoenix/"
  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_layout, content))
  end

  def is_current_tab(_, nil) do
    false
  end

  def is_current_tab(conn, tab) do
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
