defmodule PlausibleWeb.SSOController do
  use PlausibleWeb, :controller

  require Logger

  alias Plausible.Auth.SSO
  alias PlausibleWeb.LoginPreference

  alias PlausibleWeb.Router.Helpers, as: Routes

  plug Plausible.Plugs.AuthorizeTeamAccess,
       [:owner] when action in [:sso_settings]

  def login_form(conn, params) do
    login_preference = LoginPreference.get(conn)
    error = Phoenix.Flash.get(conn.assigns.flash, :login_error)

    case {login_preference, params["prefer"], error} do
      {nil, nil, nil} ->
        redirect(conn, to: Routes.auth_path(conn, :login_form, return_to: params["return_to"]))

      _ ->
        render(conn, "login_form.html")
    end
  end

  def login(conn, %{"email" => email} = params) do
    case SSO.Domains.lookup(email) do
      {:ok, %{sso_integration: integration}} ->
        redirect(conn,
          to:
            Routes.sso_path(
              conn,
              :saml_signin,
              integration.identifier,
              email: email,
              return_to: params["return_to"]
            )
        )

      {:error, :not_found} ->
        conn
        |> put_flash(:login_error, "Wrong email.")
        |> redirect(to: Routes.sso_path(conn, :login_form))
    end
  end

  def provision_notice(conn, _params) do
    render(conn, "provision_notice.html")
  end

  def provision_issue(conn, params) do
    issue =
      case params["issue"] do
        "not_a_member" -> :not_a_member
        "multiple_memberships" -> :multiple_memberships
        "multiple_memberships_noforce" -> :multiple_memberships_noforce
        "active_personal_team" -> :active_personal_team
        "active_personal_team_noforce" -> :active_personal_team_noforce
        _ -> :unknown
      end

    render(conn, "provision_issue.html", issue: issue)
  end

  def saml_signin(conn, params) do
    saml_adapter().signin(conn, params)
  end

  def saml_consume(conn, params) do
    saml_adapter().consume(conn, params)
  end

  def csp_report(conn, _params) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    Logger.error(body)
    conn |> send_resp(200, "OK")
  end

  def sso_settings(conn, _params) do
    if Plausible.Teams.setup?(conn.assigns.current_team) and Plausible.sso_enabled?() and
         Plausible.Billing.Feature.SSO.check_availability(conn.assigns.current_team) == :ok do
      render(conn, :sso_settings,
        layout: {PlausibleWeb.LayoutView, :settings},
        connect_live_socket: true
      )
    else
      conn
      |> redirect(to: Routes.site_path(conn, :index))
    end
  end

  defp saml_adapter() do
    Application.fetch_env!(:plausible, :sso_saml_adapter)
  end
end
