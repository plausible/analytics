defmodule PlausibleWeb.AuthController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  def onboarding(conn, _params) do
    if get_session(conn, :current_user_email) do
      redirect(conn, to: "/")
    else
      render(conn, "onboarding_enter_email.html")
    end
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  def send_login_link(conn, %{"email" => email}) do
    token = Phoenix.Token.sign(PlausibleWeb.Endpoint, "email_login", %{email: email})
    url = PlausibleWeb.Endpoint.url() <> "/claim-login?token=#{token}"
    require Logger
    Logger.debug(url)
    email_template = PlausibleWeb.Email.login_email(email, url)
    Plausible.Mailer.deliver_now(email_template)
    conn |> render("login_success.html", email: email)
  end

  def login_form(conn, _params) do
    render(conn, "login_form.html")
  end

  defp successful_login(email) do
    found_user = Repo.get_by(Plausible.Auth.User, email: email)
    if found_user do
      :found
    else
      Plausible.Auth.User.changeset(%Plausible.Auth.User{}, %{email: email})
        |> Plausible.Repo.insert!
      :new
    end
  end

  def claim_login_link(conn, %{"token" => token}) do
    case Phoenix.Token.verify(PlausibleWeb.Endpoint, "email_login", token, max_age: @half_hour_in_seconds) do
      {:ok, %{email: email}} ->
        conn = put_session(conn, :current_user_email, email)

        case successful_login(email) do
          :new ->
            redirect(conn, to: "/sites/new")
          :found ->
            redirect(conn, to: "/")
        end
      {:error, :expired} ->
        conn |> send_resp(401, "Your login token has expired")
      {:error, _} ->
        conn |> send_resp(400, "Your login token is invalid")
    end
  end
end
