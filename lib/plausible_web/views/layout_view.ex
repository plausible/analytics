defmodule PlausibleWeb.LayoutView do
  use PlausibleWeb, :view

  def base_domain do
    PlausibleWeb.Endpoint.host()
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def websocket_url() do
    PlausibleWeb.Endpoint.websocket_url()
  end

  def dogfood_script_url() do
    if Application.get_env(:plausible, :environment) in ["prod", "staging"] do
      "#{plausible_url()}/js/script.manual.pageview-props.tagged-events.js"
    else
      "#{plausible_url()}/js/script.local.manual.pageview-props.tagged-events.js"
    end
  end

  def dogfood_domain(conn) do
    if conn.assigns[:embedded] do
      "embed." <> base_domain()
    else
      base_domain()
    end
  end

  def dogfood_page_url(id), do: PlausibleWeb.Endpoint.url() <> dogfood_page_path(id)
  def dogfood_page_path(:dashboard), do: "/:dashboard"
  def dogfood_page_path(:shared_link), do: "/share/:dashboard"
  def dogfood_page_path(:settings_general), do: "/:dashboard/settings/general"
  def dogfood_page_path(:settings_people), do: "/:dashboard/settings/people"
  def dogfood_page_path(:settings_visibility), do: "/:dashboard/settings/visibility"
  def dogfood_page_path(:settings_goals), do: "/:dashboard/settings/goals"
  def dogfood_page_path(:settings_funnels), do: "/:dashboard/settings/funnels"
  def dogfood_page_path(:settings_props), do: "/:dashboard/settings/properties"
  def dogfood_page_path(:settings_search_console), do: "/:dashboard/settings/search-console"
  def dogfood_page_path(:settings_email_reports), do: "/:dashboard/settings/email-reports"
  def dogfood_page_path(:settings_danger_zone), do: "/:dashboard/settings/danger-zone"
  def dogfood_page_path(:register_from_invitation), do: "/register/invitation/:invitation_id"

  def home_dest(conn) do
    if conn.assigns[:current_user] do
      "/sites"
    else
      "/"
    end
  end

  def settings_tabs(conn) do
    [
      [key: "General", value: "general"],
      [key: "People", value: "people"],
      [key: "Visibility", value: "visibility"],
      [key: "Goals", value: "goals"],
      if Plausible.Funnels.enabled_for?(conn.assigns[:current_user]) do
        [key: "Funnels", value: "funnels"]
      end,
      if Plausible.Props.enabled_for?(conn.assigns[:current_user]) do
        [key: "Custom Properties", value: "properties"]
      end,
      [key: "Search Console", value: "search-console"],
      [key: "Email reports", value: "email-reports"],
      if !is_selfhost() && conn.assigns[:site].custom_domain do
        [key: "Custom domain", value: "custom-domain"]
      end,
      if conn.assigns[:current_user_role] == :owner do
        [key: "Danger zone", value: "danger-zone"]
      end
    ]
  end

  def trial_notificaton(user) do
    case Plausible.Billing.trial_days_left(user) do
      days when days > 1 ->
        "#{days} trial days left"

      days when days == 1 ->
        "Trial ends tomorrow"

      days when days == 0 ->
        "Trial ends today"
    end
  end

  def grace_period_end(%{grace_period: %{end_date: %Date{} = date}}) do
    case Timex.diff(date, Timex.today(), :days) do
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

  def is_current_tab(conn, tab) do
    List.last(conn.path_info) == tab
  end

  defp is_selfhost() do
    Application.get_env(:plausible, :is_selfhost)
  end
end
