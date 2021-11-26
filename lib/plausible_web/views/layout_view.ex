defmodule PlausibleWeb.LayoutView do
  use PlausibleWeb, :view

  def admin_email do
    Application.get_env(:plausible, :admin_email)
  end

  def base_domain do
    PlausibleWeb.Endpoint.host()
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
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
      [key: "Search Console", value: "search-console"],
      [key: "Email reports", value: "email-reports"],
      if !is_selfhost() && conn.assigns[:site].custom_domain do
        [key: "Custom domain", value: "custom-domain"]
      else
        nil
      end,
      if conn.assigns[:current_user_role] == :owner do
        [key: "Danger zone", value: "danger-zone"]
      else
        nil
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

  def on_grace_period?(nil), do: false

  def on_grace_period?(user) do
    user.grace_period &&
      Timex.diff(user.grace_period.end_date, Timex.today(), :days) >= 0
  end

  def grace_period_over?(nil), do: false

  def grace_period_over?(user) do
    user.grace_period &&
      Timex.diff(user.grace_period.end_date, Timex.today(), :days) < 0
  end

  def grace_period_end(user) do
    end_date = user.grace_period.end_date

    case Timex.diff(end_date, Timex.today(), :days) do
      0 -> "today"
      1 -> "tomorrow"
      n -> "within #{n} days"
    end
  end

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
