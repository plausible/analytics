defmodule PlausibleWeb.LayoutView do
  use PlausibleWeb, :view
  import PlausibleWeb.Components.Billing

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

  @doc """
  Temporary override to do more testing of the new ingest.plausible.io endpoint for accepting events. In staging and locally
  will fall back to staging.plausible.io/api/event and localhost:8000/api/event respectively.
  """
  def dogfood_api_destination() do
    if Application.get_env(:plausible, :environment) == "prod" do
      "https://ingest.plausible.io/api/event"
    end
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
      [key: "Funnels", value: "funnels"],
      [key: "Custom Properties", value: "properties"],
      [key: "Integrations", value: "integrations"],
      [key: "Email Reports", value: "email-reports"],
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
