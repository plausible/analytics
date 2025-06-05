defmodule PlausibleWeb.SSOController do
  use PlausibleWeb, :controller

  require Logger

  alias Plausible.Auth
  alias Plausible.Auth.SSO
  alias Plausible.Repo

  alias PlausibleWeb.Router.Helpers, as: Routes

  plug Plausible.Plugs.AuthorizeTeamAccess,
       [:owner] when action in [:sso_settings]

  def login_form(conn, params) do
    render(conn, "login_form.html", error: params["error"])
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

  def saml_signin(conn, %{
        "integration_id" => integration_id,
        "email" => email,
        "return_to" => return_to
      }) do
    conn
    |> put_layout(false)
    |> render("saml_signin.html",
      integration_id: integration_id,
      email: email,
      return_to: return_to,
      nonce: conn.private[:sso_nonce]
    )
  end

  def saml_consume(conn, %{
        "integration_id" => integration_id,
        "email" => email,
        "return_to" => return_to
      }) do
    case SSO.get_integration(integration_id) do
      {:ok, integration} ->
        session_timeout_minutes = integration.team.policy.sso_session_timeout_minutes

        expires_at =
          NaiveDateTime.add(NaiveDateTime.utc_now(:second), session_timeout_minutes, :minute)

        identity =
          if user = Repo.get_by(Auth.User, email: email) do
            %SSO.Identity{
              id: user.sso_identity_id || Ecto.UUID.generate(),
              name: user.name,
              email: email,
              expires_at: expires_at
            }
          else
            %SSO.Identity{
              id: Ecto.UUID.generate(),
              name: name_from_email(email),
              email: email,
              expires_at: expires_at
            }
          end

        PlausibleWeb.UserAuth.log_in_user(conn, identity, return_to)

      {:error, :not_found} ->
        redirect(conn,
          to: Routes.sso_path(conn, :login_form, error: "Wrong email.", return_to: return_to)
        )
    end
  end

  def csp_report(conn, _params) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    Logger.error(body)
    conn |> send_resp(200, "OK")
  end

  def sso_settings(conn, _params) do
    if Plausible.Teams.setup?(conn.assigns.current_team) do
      render(conn, :sso_settings,
        layout: {PlausibleWeb.LayoutView, :settings},
        connect_live_socket: true
      )
    else
      conn
      |> redirect(to: Routes.site_path(conn, :index))
    end
  end

  defp name_from_email(email) do
    email
    |> String.split("@", parts: 2)
    |> List.first()
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
