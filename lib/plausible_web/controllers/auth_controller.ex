defmodule PlausibleWeb.AuthController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Auth
  require Logger

  plug PlausibleWeb.RequireLoggedOutPlug when action in [:register_form, :register, :login_form, :login]
  plug PlausibleWeb.RequireAccountPlug when action in [:user_settings, :save_settings, :delete_me]

  def register_form(conn, _params) do
    changeset = Plausible.Auth.User.changeset(%Plausible.Auth.User{})
    Plausible.Tracking.event(conn, "Register: View Form")
    render(conn, "register_form.html", changeset: changeset)
  end

  def register(conn, %{"user" => params}) do
    user = Plausible.Auth.User.changeset(%Plausible.Auth.User{}, params)

    case Ecto.Changeset.apply_action(user, :insert) do
      {:ok, user} ->
        token = Auth.Token.sign_activation(user.name, user.email)
        url = PlausibleWeb.Endpoint.url() <> "/claim-activation?token=#{token}"
        Logger.debug(url)
        email_template = PlausibleWeb.Email.activation_email(user, url)
        Plausible.Mailer.deliver_now(email_template)
        Plausible.Tracking.event(conn, "Register: Submit Form")
        conn |> render("register_success.html", email: user.email)
      {:error, changeset} ->
        render(conn, "register_form.html", changeset: changeset)
    end
  end

  def claim_activation_link(conn, %{"token" => token}) do
    case Auth.Token.verify_activation(token) do
      {:ok, %{name: name, email: email}} ->
        case Auth.create_user(name, email) do
          {:ok, user} ->
            Plausible.Tracking.event(conn, "Register: Activate Account")
            Plausible.Tracking.identify(conn, user.id, %{name: user.name})
            conn
            |> put_session(:current_user_id, user.id)
            |> redirect(to: "/sites/new")
          {:error, changeset} ->
            Plausible.Tracking.event(conn, "Register: Invalid Account")
            send_resp(conn, 400, inspect(changeset.errors))
        end
      {:error, :expired} ->
        Plausible.Tracking.event(conn, "Register: Activation Failed", %{reason: :expired})

        conn
        |> put_status(401)
        |> put_view(PlausibleWeb.ErrorView)
        |> render("401.html", layout: false, message: "Your token has expired. Please request another activation link.")
      {:error, _} ->
        Plausible.Tracking.event(conn, "Register: Activation Failed", %{reason: :invalid})
        conn |> send_resp(400, "Invalid token")
        conn
        |> put_status(400)
        |> put_view(PlausibleWeb.ErrorView)
        |> render("400.html", layout: false, message: "Your token has expired. Please request another activation link.")
    end
  end

  def login(conn, %{"email" => email}) do
    case email do
      "" ->
        conn |> render("login_form.html", error: "email is required")

      email ->
        if Repo.get_by(Plausible.Auth.User, email: email) do
          token = Auth.Token.sign_login(email)
          url = PlausibleWeb.Endpoint.url() <> "/claim-login?token=#{token}"
          Logger.debug(url)
          email_template = PlausibleWeb.Email.login_email(email, url)
          Plausible.Mailer.deliver_now(email_template)
        else
          Plausible.Tracking.event(conn, "Login: User Not Found")
        end
        conn |> render("login_success.html", email: email)
    end
  end

  def login_form(conn, _params) do
    render(conn, "login_form.html")
  end

  def claim_login_link(conn, %{"token" => token}) do
    case Auth.Token.verify_login(token) do
      {:ok, %{email: email}} ->

        case Auth.find_user_by(email: email) do
          nil ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(401, "User account with email #{email} does not exist. Please sign up to get started.")
          user ->
            conn
            |> put_session(:current_user_id, user.id)
            |> redirect(to: "/")
        end
      {:error, :expired} ->
        conn |> send_resp(401, "Your login token has expired")
      {:error, _} ->
        conn |> send_resp(400, "Your login token is invalid")
    end
  end

  def user_settings(conn, _params) do
    changeset = Auth.User.changeset(conn.assigns[:current_user])
    render(conn, "user_settings.html", changeset: changeset)
  end

  def save_settings(conn, %{"user" => user_params}) do
    changes = Auth.User.changeset(conn.assigns[:current_user], user_params)
    case Repo.update(changes) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Account settings saved succesfully")
        |> redirect(to: "/settings")
      {:error, changeset} ->
        render(conn, "user_settings.html", changeset: changeset)
    end
  end

  def delete_me(conn, _params) do
    user = conn.assigns[:current_user] |> Repo.preload(:sites)

    for site_membership <- user.site_memberships do
      Repo.delete!(site_membership)
    end

    for site <- user.sites do
      Repo.delete!(site)
    end

    Repo.delete!(user)

    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end
end
