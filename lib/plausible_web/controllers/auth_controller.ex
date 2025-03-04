defmodule PlausibleWeb.AuthController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Auth
  alias Plausible.Teams
  alias PlausibleWeb.TwoFactor
  alias PlausibleWeb.UserAuth

  require Logger

  plug(
    PlausibleWeb.RequireLoggedOutPlug
    when action in [
           :register,
           :register_from_invitation,
           :login_form,
           :login,
           :verify_2fa_form,
           :verify_2fa,
           :verify_2fa_recovery_code_form,
           :verify_2fa_recovery_code
         ]
  )

  plug(
    PlausibleWeb.RequireAccountPlug
    when action in [
           :delete_me,
           :activate_form,
           :activate,
           :request_activation_code,
           :initiate_2fa,
           :verify_2fa_setup_form,
           :verify_2fa_setup,
           :disable_2fa,
           :generate_2fa_recovery_codes,
           :select_team,
           :switch_team
         ]
  )

  plug(
    :clear_2fa_user
    when action not in [
           :verify_2fa_form,
           :verify_2fa,
           :verify_2fa_recovery_code_form,
           :verify_2fa_recovery_code
         ]
  )

  # Plug purging 2FA user session cookie outsite 2FA flow
  defp clear_2fa_user(conn, _opts) do
    TwoFactor.Session.clear_2fa_user(conn)
  end

  def select_team(conn, _params) do
    current_user = conn.assigns.current_user

    owner_name_fn = fn owner ->
      if owner.id == current_user.id do
        "You"
      else
        owner.name
      end
    end

    teams =
      current_user
      |> Teams.Users.teams()
      |> Enum.map(fn team ->
        current_team? = team.id == conn.assigns.current_team.id

        owners =
          Enum.map_join(team.owners, ", ", &owner_name_fn.(&1))

        many_owners? = length(team.owners) > 1

        %{
          identifier: team.identifier,
          name: team.name,
          current?: current_team?,
          many_owners?: many_owners?,
          owners: owners
        }
      end)

    render(conn, "select_team.html", teams: teams)
  end

  def switch_team(conn, params) do
    current_user = conn.assigns.current_user
    team_id = params["team_id"]
    team = if team_id != "none", do: Teams.get(params["team_id"])

    cond do
      team ->
        case Teams.Memberships.team_role(team, current_user) do
          {:ok, role} when role != :guest ->
            conn
            |> put_session("current_team_id", team.identifier)
            |> redirect(to: Routes.site_path(conn, :index))

          _ ->
            conn
            |> put_flash(:error, "You have select an invalid team")
            |> redirect(to: Routes.site_path(conn, :index))
        end

      team_id == "none" ->
        conn
        |> delete_session("current_team_id")
        |> redirect(to: Routes.site_path(conn, :index))

      true ->
        conn
        |> put_flash(:error, "You have select an invalid team")
        |> redirect(to: Routes.site_path(conn, :index))
    end
  end

  def activate_form(conn, params) do
    user = conn.assigns.current_user
    flow = params["flow"] || PlausibleWeb.Flows.register()

    render(conn, "activate.html",
      error: nil,
      has_email_code?: Plausible.Users.has_email_code?(user),
      has_any_memberships?: Plausible.Teams.Users.has_sites?(user),
      form_submit_url: "/activate?flow=#{flow}"
    )
  end

  def activate(conn, %{"code" => code}) do
    user = conn.assigns[:current_user]

    has_any_invitations? = Plausible.Teams.Users.has_sites?(user, include_pending?: true)
    has_any_memberships? = Plausible.Teams.Users.has_sites?(user, include_pending?: false)

    flow = conn.params["flow"]

    case Auth.EmailVerification.verify_code(user, code) do
      :ok ->
        cond do
          has_any_memberships? ->
            handle_email_updated(conn)

          has_any_invitations? ->
            redirect(conn, to: Routes.site_path(conn, :index, flow: flow))

          true ->
            redirect(conn, to: Routes.site_path(conn, :new, flow: flow))
        end

      {:error, :incorrect} ->
        render(conn, "activate.html",
          error: "Incorrect activation code",
          has_email_code?: true,
          has_any_memberships?: has_any_memberships?,
          form_submit_url: "/activate?flow=#{flow}"
        )

      {:error, :expired} ->
        render(conn, "activate.html",
          error: "Code is expired, please request another one",
          has_email_code?: false,
          has_any_memberships?: has_any_memberships?,
          form_submit_url: "/activate?flow=#{flow}"
        )
    end
  end

  def request_activation_code(conn, _params) do
    user = conn.assigns.current_user
    Auth.EmailVerification.issue_code(user)

    conn
    |> put_flash(:success, "Activation code was sent to #{user.email}")
    |> redirect(to: Routes.auth_path(conn, :activate_form))
  end

  def password_reset_request_form(conn, _) do
    render(conn, "password_reset_request_form.html")
  end

  def password_reset_request(conn, %{"email" => ""}) do
    render(conn, "password_reset_request_form.html", error: "Please enter an email address")
  end

  def password_reset_request(conn, %{"email" => email} = params) do
    if PlausibleWeb.Captcha.verify(params["h-captcha-response"]) do
      user = Repo.get_by(Plausible.Auth.User, email: email)

      if user do
        token = Auth.Token.sign_password_reset(email)
        url = PlausibleWeb.Endpoint.url() <> "/password/reset?token=#{token}"
        email_template = PlausibleWeb.Email.password_reset_email(email, url)
        Plausible.Mailer.deliver_later(email_template)

        Logger.debug(
          "Password reset e-mail sent. In dev environment GET /sent-emails for details."
        )

        render(conn, "password_reset_request_success.html", email: email)
      else
        render(conn, "password_reset_request_success.html", email: email)
      end
    else
      render(conn, "password_reset_request_form.html",
        error: "Please complete the captcha to reset your password"
      )
    end
  end

  def password_reset_form(conn, params) do
    case Auth.Token.verify_password_reset(params["token"]) do
      {:ok, %{email: email}} ->
        render(conn, "password_reset_form.html",
          connect_live_socket: true,
          email: email
        )

      {:error, :expired} ->
        render_error(
          conn,
          401,
          "Your token has expired. Please request another password reset link."
        )

      {:error, _} ->
        render_error(
          conn,
          401,
          "Your token is invalid. Please request another password reset link."
        )
    end
  end

  def password_reset(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> put_flash(:login_title, "Password updated successfully")
    |> put_flash(:login_instructions, "Please log in with your new credentials")
    |> redirect(to: Routes.auth_path(conn, :login_form))
  end

  def login_form(conn, _params) do
    render(conn, "login_form.html")
  end

  def login(conn, %{"user" => params}) do
    login(conn, params)
  end

  def login(conn, %{"email" => email, "password" => password} = params) do
    with :ok <- Auth.rate_limit(:login_ip, conn),
         {:ok, user} <- Auth.get_user_by(email: email),
         :ok <- Auth.rate_limit(:login_user, user),
         :ok <- Auth.check_password(user, password),
         :ok <- check_2fa_verified(conn, user) do
      redirect_path =
        cond do
          not is_nil(params["register_action"]) and not user.email_verified ->
            Auth.EmailVerification.issue_code(user)

            flow =
              if params["register_action"] == "register_form" do
                PlausibleWeb.Flows.register()
              else
                PlausibleWeb.Flows.invitation()
              end

            Routes.auth_path(conn, :activate_form, flow: flow)

          params["register_action"] == "register_from_invitation_form" ->
            Routes.site_path(conn, :index)

          params["register_action"] == "register_form" ->
            Routes.site_path(conn, :new)

          true ->
            params["return_to"]
        end

      UserAuth.log_in_user(conn, user, redirect_path)
    else
      {:error, :wrong_password} ->
        maybe_log_failed_login_attempts("wrong password for #{email}")

        render(conn, "login_form.html", error: "Wrong email or password. Please try again.")

      {:error, :user_not_found} ->
        maybe_log_failed_login_attempts("user not found for #{email}")
        Plausible.Auth.Password.dummy_calculation()

        render(conn, "login_form.html", error: "Wrong email or password. Please try again.")

      {:error, {:rate_limit, _}} ->
        maybe_log_failed_login_attempts("too many login attempts for #{email}")

        render_error(
          conn,
          429,
          "Too many login attempts. Wait a minute before trying again."
        )

      {:error, {:unverified_2fa, user}} ->
        query_params =
          if params["return_to"] not in [nil, ""], do: [return_to: params["return_to"]], else: []

        conn
        |> TwoFactor.Session.set_2fa_user(user)
        |> redirect(to: Routes.auth_path(conn, :verify_2fa, query_params))
    end
  end

  defp check_2fa_verified(conn, user) do
    if Auth.TOTP.enabled?(user) and not TwoFactor.Session.remember_2fa?(conn, user) do
      {:error, {:unverified_2fa, user}}
    else
      :ok
    end
  end

  def initiate_2fa_setup(conn, _params) do
    case Auth.TOTP.initiate(conn.assigns.current_user) do
      {:ok, user, %{totp_uri: totp_uri, secret: secret}} ->
        render(conn, "initiate_2fa_setup.html", user: user, totp_uri: totp_uri, secret: secret)

      {:error, :already_setup} ->
        conn
        |> put_flash(:error, "Two-Factor Authentication is already setup for this account.")
        |> redirect(to: Routes.settings_path(conn, :security) <> "#update-2fa")
    end
  end

  def verify_2fa_setup_form(conn, _params) do
    if Auth.TOTP.initiated?(conn.assigns.current_user) do
      render(conn, "verify_2fa_setup.html")
    else
      redirect(conn, to: Routes.settings_path(conn, :security) <> "#update-2fa")
    end
  end

  def verify_2fa_setup(conn, %{"code" => code}) do
    case Auth.TOTP.enable(conn.assigns.current_user, code) do
      {:ok, _, %{recovery_codes: codes}} ->
        conn
        |> put_flash(:success, "Two-Factor Authentication is fully enabled")
        |> render("generate_2fa_recovery_codes.html", recovery_codes: codes, from_setup: true)

      {:error, :invalid_code} ->
        conn
        |> put_flash(:error, "The provided code is invalid. Please try again")
        |> render("verify_2fa_setup.html")

      {:error, :not_initiated} ->
        conn
        |> put_flash(:error, "Please enable Two-Factor Authentication for this account first.")
        |> redirect(to: Routes.settings_path(conn, :security) <> "#update-2fa")
    end
  end

  def disable_2fa(conn, %{"password" => password}) do
    case Auth.TOTP.disable(conn.assigns.current_user, password) do
      {:ok, _} ->
        conn
        |> TwoFactor.Session.clear_remember_2fa()
        |> put_flash(:success, "Two-Factor Authentication is disabled")
        |> redirect(to: Routes.settings_path(conn, :security) <> "#update-2fa")

      {:error, :invalid_password} ->
        conn
        |> put_flash(:error, "Incorrect password provided")
        |> redirect(to: Routes.settings_path(conn, :security) <> "#update-2fa")
    end
  end

  def generate_2fa_recovery_codes(conn, %{"password" => password}) do
    case Auth.TOTP.generate_recovery_codes(conn.assigns.current_user, password) do
      {:ok, codes} ->
        conn
        |> put_flash(:success, "New Recovery Codes generated")
        |> render("generate_2fa_recovery_codes.html", recovery_codes: codes, from_setup: false)

      {:error, :invalid_password} ->
        conn
        |> put_flash(:error, "Incorrect password provided")
        |> redirect(to: Routes.settings_path(conn, :security) <> "#update-2fa")

      {:error, :not_enabled} ->
        conn
        |> put_flash(:error, "Please enable Two-Factor Authentication for this account first.")
        |> redirect(to: Routes.settings_path(conn, :security) <> "#update-2fa")
    end
  end

  def verify_2fa_form(conn, _params) do
    case TwoFactor.Session.get_2fa_user(conn) do
      {:ok, user} ->
        if Auth.TOTP.enabled?(user) do
          render(conn, "verify_2fa.html",
            remember_2fa_days: TwoFactor.Session.remember_2fa_days()
          )
        else
          redirect_to_login(conn)
        end

      {:error, :not_found} ->
        redirect_to_login(conn)
    end
  end

  def verify_2fa(conn, %{"code" => code} = params) do
    with {:ok, user} <- get_2fa_user_limited(conn) do
      case Auth.TOTP.validate_code(user, code) do
        {:ok, user} ->
          conn
          |> TwoFactor.Session.maybe_set_remember_2fa(user, params["remember_2fa"])
          |> UserAuth.log_in_user(user, params["return_to"])

        {:error, :invalid_code} ->
          maybe_log_failed_login_attempts(
            "wrong 2FA verification code provided for #{user.email}"
          )

          conn
          |> put_flash(:error, "The provided code is invalid. Please try again")
          |> render("verify_2fa.html",
            remember_2fa_days: TwoFactor.Session.remember_2fa_days()
          )

        {:error, :not_enabled} ->
          UserAuth.log_in_user(conn, user, params["return_to"])
      end
    end
  end

  def verify_2fa_recovery_code_form(conn, _params) do
    case TwoFactor.Session.get_2fa_user(conn) do
      {:ok, user} ->
        if Auth.TOTP.enabled?(user) do
          render(conn, "verify_2fa_recovery_code.html")
        else
          redirect_to_login(conn)
        end

      {:error, :not_found} ->
        redirect_to_login(conn)
    end
  end

  def verify_2fa_recovery_code(conn, %{"recovery_code" => recovery_code}) do
    with {:ok, user} <- get_2fa_user_limited(conn) do
      case Auth.TOTP.use_recovery_code(user, recovery_code) do
        :ok ->
          UserAuth.log_in_user(conn, user)

        {:error, :invalid_code} ->
          maybe_log_failed_login_attempts("wrong 2FA recovery code provided for #{user.email}")

          conn
          |> put_flash(:error, "The provided recovery code is invalid. Please try another one")
          |> render("verify_2fa_recovery_code.html")

        {:error, :not_enabled} ->
          UserAuth.log_in_user(conn, user)
      end
    end
  end

  defp get_2fa_user_limited(conn) do
    case TwoFactor.Session.get_2fa_user(conn) do
      {:ok, user} ->
        with :ok <- Auth.rate_limit(:login_ip, conn),
             :ok <- Auth.rate_limit(:login_user, user) do
          {:ok, user}
        else
          {:error, {:rate_limit, _}} ->
            maybe_log_failed_login_attempts("too many login attempts for #{user.email}")

            conn
            |> TwoFactor.Session.clear_2fa_user()
            |> render_error(
              429,
              "Too many login attempts. Wait a minute before trying again."
            )
        end

      {:error, :not_found} ->
        conn
        |> redirect(to: Routes.auth_path(conn, :login_form))
    end
  end

  defp handle_email_updated(conn) do
    conn
    |> put_flash(:success, "Email updated successfully")
    |> redirect(to: Routes.settings_path(conn, :security) <> "#update-email")
  end

  def delete_me(conn, params) do
    case Plausible.Auth.delete_user(conn.assigns[:current_user]) do
      {:ok, :deleted} ->
        logout(conn, params)

      {:error, :is_only_team_owner} ->
        conn
        |> put_flash(
          :error,
          "You can't delete your account when you are the only owner on a team."
        )
        |> redirect(to: Routes.settings_path(conn, :danger_zone))
    end
  end

  def logout(conn, params) do
    redirect_to = Map.get(params, "redirect", "/")

    conn
    |> UserAuth.log_out_user()
    |> redirect(to: redirect_to)
  end

  def google_auth_callback(conn, %{"error" => error, "state" => state} = params) do
    [site_id, redirected_to | _] = Jason.decode!(state)

    site = Repo.get(Plausible.Site, site_id)

    redirect_route =
      if redirected_to == "import" do
        Routes.site_path(conn, :settings_imports_exports, site.domain)
      else
        Routes.site_path(conn, :settings_integrations, site.domain)
      end

    case error do
      "access_denied" ->
        conn
        |> put_flash(
          :error,
          "We were unable to authenticate your Google Analytics account. Please check that you have granted us permission to 'See and download your Google Analytics data' and try again."
        )
        |> redirect(external: redirect_route)

      message when message in ["server_error", "temporarily_unavailable"] ->
        conn
        |> put_flash(
          :error,
          "We are unable to authenticate your Google Analytics account because Google's authentication service is temporarily unavailable. Please try again in a few moments."
        )
        |> redirect(external: redirect_route)

      _any ->
        Sentry.capture_message("Google OAuth callback failed. Reason: #{inspect(params)}")

        conn
        |> put_flash(
          :error,
          "We were unable to authenticate your Google Analytics account. If the problem persists, please contact support for assistance."
        )
        |> redirect(external: redirect_route)
    end
  end

  def google_auth_callback(conn, %{"code" => code, "state" => state}) do
    res = Plausible.Google.API.fetch_access_token!(code)

    [site_id, redirect_to | _] = Jason.decode!(state)

    site = Repo.get(Plausible.Site, site_id)
    expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), res["expires_in"])

    case redirect_to do
      "import" ->
        redirect(conn,
          external:
            Routes.google_analytics_path(conn, :property_form, site.domain,
              access_token: res["access_token"],
              refresh_token: res["refresh_token"],
              expires_at: NaiveDateTime.to_iso8601(expires_at)
            )
        )

      _ ->
        id_token = res["id_token"]
        [_, body, _] = String.split(id_token, ".")
        id = body |> Base.decode64!(padding: false) |> Jason.decode!()

        Plausible.Site.GoogleAuth.changeset(%Plausible.Site.GoogleAuth{}, %{
          email: id["email"],
          refresh_token: res["refresh_token"],
          access_token: res["access_token"],
          expires: expires_at,
          user_id: conn.assigns[:current_user].id,
          site_id: site_id
        })
        |> Repo.insert!()

        site = Repo.get(Plausible.Site, site_id)

        redirect(conn, external: "/#{URI.encode_www_form(site.domain)}/settings/integrations")
    end
  end

  defp redirect_to_login(conn) do
    redirect(conn, to: Routes.auth_path(conn, :login_form))
  end

  defp maybe_log_failed_login_attempts(message) do
    if Application.get_env(:plausible, :log_failed_login_attempts) do
      Logger.warning("[login] #{message}")
    end
  end
end
