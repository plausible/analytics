defmodule PlausibleWeb.LayoutView do
  use PlausibleWeb, :view
  use Plausible
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
      "/sites"
    else
      "/"
    end
  end

  def settings_tabs(conn) do
    [
      [key: "General", value: "general", icon: :rocket_launch],
      [key: "People", value: "people", icon: :users],
      [key: "Visibility", value: "visibility", icon: :eye],
      [key: "Goals", value: "goals", icon: :check_circle],
      on_full_build do
        [key: "Funnels", value: "funnels", icon: :funnel]
      end,
      [key: "Custom Properties", value: "properties", icon: :document_text],
      [key: "Integrations", value: "integrations", icon: :arrow_path_rounded_square],
      [key: "Email Reports", value: "email-reports", icon: :envelope],
      if conn.assigns[:current_user_role] == :owner do
        [key: "Danger Zone", value: "danger-zone", icon: :exclamation_triangle]
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
end
