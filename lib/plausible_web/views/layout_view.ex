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
