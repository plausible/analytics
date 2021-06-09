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

  def settings_tabs() do
    [
      [key: "General", value: "general"],
      [key: "Visibility", value: "visibility"],
      [key: "Goals", value: "goals"],
      [key: "Search Console", value: "search-console"],
      [key: "Email reports", value: "email-reports"],
      if !is_selfhost() do
        [key: "Custom domain", value: "custom-domain"]
      else
        nil
      end,
      [key: "Danger zone", value: "danger-zone"]
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
