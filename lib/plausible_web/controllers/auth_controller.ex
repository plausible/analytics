defmodule PlausibleWeb.AuthController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Auth
  require Logger

  plug PlausibleWeb.RequireLoggedOutPlug when action in [:register_form, :register, :login_form, :login]
  plug PlausibleWeb.RequireAccountPlug when action in [:user_settings, :save_settings, :delete_me, :password_form, :set_password]

  def register_form(conn, _params) do
    changeset = Plausible.Auth.User.changeset(%Plausible.Auth.User{})
    render(conn, "register_form.html", changeset: changeset, layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def register(conn, %{"user" => params}) do
    user = Plausible.Auth.User.changeset(%Plausible.Auth.User{}, params)

    case Ecto.Changeset.apply_action(user, :insert) do
      {:ok, user} ->
        token = Auth.Token.sign_activation(user.name, user.email)
        url = PlausibleWeb.Endpoint.clean_url() <> "/claim-activation?token=#{token}"
        Logger.info(url)
        email_template = PlausibleWeb.Email.activation_email(user, url)
        Plausible.Mailer.send_email(email_template)
        conn |> render("register_success.html", email: user.email, layout: {PlausibleWeb.LayoutView, "focus.html"})
      {:error, changeset} ->
        render(conn, "register_form.html", changeset: changeset, layout: {PlausibleWeb.LayoutView, "focus.html"})
    end
  end

  def claim_activation_link(conn, %{"token" => token}) do
    case Auth.Token.verify_activation(token) do
      {:ok, %{name: name, email: email}} ->
        case Auth.create_user(name, email) do
          {:ok, user} ->
            PlausibleWeb.Email.welcome_email(user)
            |> Plausible.Mailer.send_email()

            conn
            |> put_session(:current_user_id, user.id)
            |> put_resp_cookie("logged_in", "true", http_only: false)
            |> redirect(to: "/password")
          {:error, changeset} ->
            send_resp(conn, 400, inspect(changeset.errors))
        end
      {:error, :expired} ->
        render_error(conn, 401, "Your token has expired. Please request another activation link.")
      {:error, _} ->
        render_error(conn, 400, "Your token is invalid. Please request another activation link.")
    end
  end

  def password_reset_request_form(conn, _) do
    render(conn, "password_reset_request_form.html", layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def password_reset_request(conn, %{"email" => ""}) do
    render(conn, "password_reset_request_form.html", error: "Please enter an email address", layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def password_reset_request(conn, %{"email" => email}) do
    user = Repo.get_by(Plausible.Auth.User, email: email)

    if user do
      token = Auth.Token.sign_password_reset(email)
      url = PlausibleWeb.Endpoint.clean_url() <> "/password/reset?token=#{token}"
      Logger.debug("PASSWORD RESET LINK: " <> url)
      email_template = PlausibleWeb.Email.password_reset_email(email, url)
      Plausible.Mailer.deliver_now(email_template)
      render(conn, "password_reset_request_success.html", email: email, layout: {PlausibleWeb.LayoutView, "focus.html"})
    else
      render(conn, "password_reset_request_success.html", email: email, layout: {PlausibleWeb.LayoutView, "focus.html"})
    end
  end

  def password_reset_form(conn, %{"token" => token}) do
    case Auth.Token.verify_password_reset(token) do
      {:ok, _} ->
        render(conn, "password_reset_form.html", token: token, layout: {PlausibleWeb.LayoutView, "focus.html"})
      {:error, :expired} ->
        render_error(conn, 401, "Your token has expired. Please request another password reset link.")
      {:error, _} ->
        render_error(conn, 401, "Your token is invalid. Please request another password reset link.")
    end
  end

  def password_reset(conn, %{"token" => token, "password" => pw}) do
    case Auth.Token.verify_password_reset(token) do
      {:ok, %{email: email}} ->
        user = Repo.get_by(Auth.User, email: email)
        changeset = Auth.User.set_password(user, pw)
        case Repo.update(changeset) do
          {:ok, _updated} ->
            conn
            |> put_flash(:login_title, "Password updated successfully")
            |> put_flash(:login_instructions, "Please log in with your new credentials")
            |> put_session(:current_user_id, nil)
            |> delete_resp_cookie("logged_in")
            |> redirect(to: "/login")
          {:error, changeset} ->
            render(conn, "password_reset_form.html", changeset: changeset, token: token, layout: {PlausibleWeb.LayoutView, "focus.html"})
        end
      {:error, :expired} ->
        render_error(conn, 401, "Your token has expired. Please request another password reset link.")
      {:error, _} ->
        render_error(conn, 401, "Your token is invalid. Please request another password reset link.")
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    alias Plausible.Auth.Password

    user = Repo.one(
      from u in Plausible.Auth.User,
      where: u.email == ^email
    )

    if user do
      if Password.match?(password, user.password_hash || "") do
        login_dest = get_session(conn, :login_dest) || "/sites"

        conn
        |> put_session(:current_user_id, user.id)
        |> put_resp_cookie("logged_in", "true", http_only: false)
        |> put_session(:login_dest, nil)
        |> redirect(to: login_dest)
      else
        conn |> render("login_form.html", error: "Wrong email or password. Please try again.", layout: {PlausibleWeb.LayoutView, "focus.html"})
      end
    else
      Password.dummy_calculation()
      conn |> render("login_form.html", error: "Wrong email or password. Please try again.", layout: {PlausibleWeb.LayoutView, "focus.html"})
    end
  end

  def login_form(conn, _params) do
    render(conn, "login_form.html", layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def password_form(conn, _params) do
    render(conn, "password_form.html", layout: {PlausibleWeb.LayoutView, "focus.html"}, skip_plausible_tracking: true)
  end

  def set_password(conn, %{"password" => pw}) do
    changeset = Auth.User.set_password(conn.assigns[:current_user], pw)

    case Repo.update(changeset) do
      {:ok, _user} ->
        redirect(conn, to: "/sites/new")
      {:error, changeset} ->
        render(conn, "password_form.html", changeset: changeset, layout: {PlausibleWeb.LayoutView, "focus.html"})
    end
  end

  def user_settings(conn, _params) do
    changeset = Auth.User.changeset(conn.assigns[:current_user])
    subscription = Plausible.Billing.active_subscription_for(conn.assigns[:current_user].id)
    render(conn, "user_settings.html", changeset: changeset, subscription: subscription)
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

  def delete_me(conn, params) do
    user = conn.assigns[:current_user]
           |> Repo.preload(:sites)
           |> Repo.preload(:subscription)

    for site_membership <- user.site_memberships do
      Repo.delete!(site_membership)
    end

    for site <- user.sites do
      Repo.delete!(site)
    end

    if user.subscription, do: Repo.delete!(user.subscription)
    Repo.delete!(user)

    logout(conn, params)
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> delete_resp_cookie("logged_in")
    |> redirect(to: "/")
  end

  def google_auth_callback(conn, %{"code" => code, "state" => site_id}) do
    res = Plausible.Google.Api.fetch_access_token(code)
    id_token = res["id_token"]
    [_, body, _] = String.split(id_token, ".")
    id = body |> Base.decode64!(padding: false) |> Jason.decode!

    Plausible.Site.GoogleAuth.changeset(%Plausible.Site.GoogleAuth{}, %{
      email: id["email"],
      refresh_token: res["refresh_token"],
      access_token: res["access_token"],
      expires: NaiveDateTime.utc_now() |> NaiveDateTime.add(res["expires_in"]),
      user_id: conn.assigns[:current_user].id,
      site_id: site_id
    }) |> Repo.insert!

    site = Repo.get(Plausible.Site, site_id)

    redirect(conn, to: "/#{URI.encode_www_form(site.domain)}/settings#google-auth")
  end
end
