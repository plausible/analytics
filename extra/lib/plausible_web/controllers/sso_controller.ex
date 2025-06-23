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

    case {login_preference, params["prefer"]} do
      {nil, nil} ->
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
        render(conn, "login_form.html", error: "Wrong email.")
    end
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
    if Plausible.Teams.setup?(conn.assigns.current_team) and Plausible.sso_enabled?() do
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
