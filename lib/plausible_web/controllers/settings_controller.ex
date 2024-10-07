defmodule PlausibleWeb.SettingsController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Auth
  alias PlausibleWeb.UserAuth

  alias Plausible.Billing.Quota

  require Logger

  def index(conn, _params) do
    redirect(conn, to: Routes.settings_path(conn, :preferences))
  end

  def preferences(conn, _params) do
    render_preferences(conn)
  end

  def security(conn, _params) do
    render_security(conn)
  end

  def subscription(conn, _params) do
    current_user = conn.assigns.current_user

    render(conn, :subscription,
      layout: {PlausibleWeb.LayoutView, :settings},
      subscription: current_user.subscription,
      pageview_limit: Quota.Limits.monthly_pageview_limit(current_user),
      pageview_usage: Quota.Usage.monthly_pageview_usage(current_user),
      site_usage: Quota.Usage.site_usage(current_user),
      site_limit: Quota.Limits.site_limit(current_user),
      team_member_limit: Quota.Limits.team_member_limit(current_user),
      team_member_usage: Quota.Usage.team_member_usage(current_user)
    )
  end

  def invoices(conn, _params) do
    current_user = conn.assigns.current_user
    invoices = Plausible.Billing.paddle_api().get_invoices(current_user.subscription)
    render(conn, :invoices, layout: {PlausibleWeb.LayoutView, :settings}, invoices: invoices)
  end

  def api_keys(conn, _params) do
    current_user = conn.assigns.current_user

    api_keys =
      Repo.preload(current_user, :api_keys).api_keys

    render(conn, :api_keys, layout: {PlausibleWeb.LayoutView, :settings}, api_keys: api_keys)
  end

  def danger_zone(conn, _params) do
    render(conn, :danger_zone, layout: {PlausibleWeb.LayoutView, :settings})
  end

  # Preferences actions

  def update_name(conn, %{"user" => params}) do
    changeset = Auth.User.name_changeset(conn.assigns.current_user, params)

    case Repo.update(changeset) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Name changed")
        |> redirect(to: Routes.settings_path(conn, :preferences) <> "#update-name")

      {:error, changeset} ->
        render_preferences(conn, name_changeset: changeset)
    end
  end

  def update_theme(conn, %{"user" => params}) do
    changeset = Auth.User.theme_changeset(conn.assigns.current_user, params)

    case Repo.update(changeset) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Theme changed")
        |> redirect(to: Routes.settings_path(conn, :preferences) <> "#update-theme")

      {:error, changeset} ->
        render_preferences(conn, theme_changeset: changeset)
    end
  end

  defp render_preferences(conn, opts \\ []) do
    name_changeset =
      Keyword.get(opts, :name_changeset, Auth.User.name_changeset(conn.assigns.current_user))

    theme_changeset =
      Keyword.get(opts, :theme_changeset, Auth.User.theme_changeset(conn.assigns.current_user))

    render(conn, :preferences,
      name_changeset: name_changeset,
      theme_changeset: theme_changeset,
      layout: {PlausibleWeb.LayoutView, :settings}
    )
  end

  # Security actions

  def update_email(conn, %{"user" => params}) do
    user = conn.assigns.current_user

    with :ok <- Auth.rate_limit(:email_change_user, user),
         changes = Auth.User.email_changeset(user, params),
         {:ok, user} <- Repo.update(changes) do
      if user.email_verified do
        handle_email_updated(conn)
      else
        Auth.EmailVerification.issue_code(user)
        redirect(conn, to: Routes.auth_path(conn, :activate_form))
      end
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render_security(conn, email_changeset: changeset)

      {:error, {:rate_limit, _}} ->
        changeset =
          user
          |> Auth.User.email_changeset(params)
          |> Ecto.Changeset.add_error(:email, "too many requests, try again in an hour")
          |> Map.put(:action, :validate)

        render_security(conn, email_changeset: changeset)
    end
  end

  def cancel_update_email(conn, _params) do
    IO.inspect :HIT
    changeset = Auth.User.cancel_email_changeset(conn.assigns.current_user)

    case Repo.update(changeset) do
      {:ok, user} ->
        conn
        |> put_flash(:success, "Email changed back to #{user.email}")
        |> redirect(to: Routes.settings_path(conn, :security) <> "#update-email")

      {:error, _} ->
        conn
        |> put_flash(
          :error,
          "Could not cancel email update because previous email has already been taken"
        )
        |> redirect(to: Routes.auth_path(conn, :activate_form))
    end
  end

  def update_password(conn, %{"user" => params}) do
    user = conn.assigns.current_user
    user_session = conn.assigns.current_user_session

    with :ok <- Auth.rate_limit(:password_change_user, user),
         {:ok, user} <- do_update_password(user, params) do
      UserAuth.revoke_all_user_sessions(user, except: user_session)

      conn
      |> put_flash(:success, "Your password is now changed")
      |> redirect(to: Routes.settings_path(conn, :security) <> "#update-password")
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render_security(conn, password_changeset: changeset)

      {:error, {:rate_limit, _}} ->
        changeset =
          user
          |> Auth.User.password_changeset(params)
          |> Ecto.Changeset.add_error(:password, "too many attempts, try again in 20 minutes")
          |> Map.put(:action, :validate)

        render_security(conn, password_changeset: changeset)
    end
  end

  defp render_security(conn, opts \\ []) do
    user_sessions = Auth.UserSessions.list_for_user(conn.assigns.current_user)

    email_changeset =
      Keyword.get(
        opts,
        :email_changeset,
        Auth.User.email_changeset(conn.assigns.current_user, %{email: ""})
      )

    password_changeset =
      Keyword.get(
        opts,
        :password_changeset,
        Auth.User.password_changeset(conn.assigns.current_user)
      )

    render(conn, :security,
      totp_enabled?: Auth.TOTP.enabled?(conn.assigns.current_user),
      user_sessions: user_sessions,
      email_changeset: email_changeset,
      password_changeset: password_changeset,
      layout: {PlausibleWeb.LayoutView, :settings}
    )
  end

  defp do_update_password(user, params) do
    changes = Auth.User.password_changeset(user, params)

    Repo.transaction(fn ->
      with {:ok, user} <- Repo.update(changes),
           {:ok, user} <- validate_2fa_code(user, params["two_factor_code"]) do
        user
      else
        {:error, :invalid_2fa} ->
          changes
          |> Ecto.Changeset.add_error(:password, "invalid 2FA code")
          |> Map.put(:action, :validate)
          |> Repo.rollback()

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp validate_2fa_code(user, code) do
    if Auth.TOTP.enabled?(user) do
      case Auth.TOTP.validate_code(user, code) do
        {:ok, user} -> {:ok, user}
        {:error, :not_enabled} -> {:ok, user}
        {:error, _} -> {:error, :invalid_2fa}
      end
    else
      {:ok, user}
    end
  end

  defp handle_email_updated(conn) do
    conn
    |> put_flash(:success, "Email updated")
    |> redirect(to: Routes.settings_path(conn, :security) <> "#update-email")
  end
end
