defmodule PlausibleWeb.UserAuth do
  @moduledoc """
  Functions for user session management.
  """

  use Plausible

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias PlausibleWeb.TwoFactor

  alias PlausibleWeb.Router.Helpers, as: Routes

  require Logger

  on_ee do
    @type login_subject() :: Auth.User.t() | Auth.SSO.Identity.t()
  else
    @type login_subject() :: Auth.User.t()
  end

  @spec log_in_user(Plug.Conn.t(), login_subject(), String.t() | nil) ::
          Plug.Conn.t()
  def log_in_user(conn, subject, redirect_path \\ nil)

  def log_in_user(conn, %Auth.User{} = user, redirect_path) do
    redirect_to = login_redirect_path(conn, redirect_path)
    {token, _} = create_user_session(conn, user)

    conn
    |> set_user_token(token)
    |> set_logged_in_cookie()
    |> Phoenix.Controller.redirect(to: redirect_to)
  end

  on_ee do
    def log_in_user(conn, %Auth.SSO.Identity{} = identity, redirect_path) do
      case Auth.SSO.provision_user(identity) do
        {:ok, provisioning_from, user} ->
          if provisioning_from == :standard do
            :ok = revoke_all_user_sessions(user)
          end

          redirect_to = login_redirect_path(conn, redirect_path)
          {token, _} = create_sso_user_session(conn, user, identity.expires_at)

          conn
          |> set_user_token(token)
          |> set_logged_in_cookie()
          |> Phoenix.Controller.redirect(to: redirect_to)

        {:error, :integration_not_found} ->
          conn
          |> log_out_user()
          |> Phoenix.Controller.redirect(to: "/")

        {:error, :multiple_memberships, team, user} ->
          redirect_path = Routes.site_path(conn, :index, __team: team.identifier)

          log_in_user(conn, user, redirect_path)
      end
    end

    defp create_sso_user_session(conn, user, expires_at) do
      device_name = get_device_name(conn)

      user_session =
        user
        |> Auth.UserSession.new_sso_session(device_name, expires_at)
        |> Repo.insert!()

      {user_session.token, user_session}
    end
  end

  @spec log_out_user(Plug.Conn.t()) :: Plug.Conn.t()
  def log_out_user(conn) do
    case get_user_token(conn) do
      {:ok, token} -> remove_user_session(token)
      {:error, _} -> :pass
    end

    if live_socket_id = Plug.Conn.get_session(conn, :live_socket_id) do
      PlausibleWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> clear_logged_in_cookie()
  end

  @spec get_user_session(Plug.Conn.t() | map()) ::
          {:ok, Auth.UserSession.t()} | {:error, :no_valid_token | :session_not_found}
  def get_user_session(%Plug.Conn{assigns: %{current_user_session: user_session}}) do
    {:ok, user_session}
  end

  def get_user_session(conn_or_session) do
    with {:ok, token} <- get_user_token(conn_or_session) do
      get_session_by_token(token)
    end
  end

  @spec touch_user_session(Auth.UserSession.t(), NaiveDateTime.t()) :: Auth.UserSession.t()
  def touch_user_session(user_session, now \\ NaiveDateTime.utc_now(:second)) do
    if NaiveDateTime.diff(now, user_session.last_used_at, :hour) >= 1 do
      Plausible.Users.bump_last_seen(user_session.user_id, now)

      user_session
      |> Repo.preload(:user)
      |> Auth.UserSession.touch_session(now)
      |> Repo.update!(allow_stale: true)
    else
      user_session
    end
  end

  @spec revoke_user_session(Auth.User.t(), pos_integer()) :: :ok
  def revoke_user_session(user, session_id) do
    {_, tokens} =
      Repo.delete_all(
        from us in Auth.UserSession,
          where: us.user_id == ^user.id and us.id == ^session_id,
          select: us.token
      )

    case tokens do
      [token] ->
        PlausibleWeb.Endpoint.broadcast(live_socket_id(token), "disconnect", %{})

      _ ->
        :pass
    end

    :ok
  end

  @spec revoke_all_user_sessions(Auth.User.t(), Keyword.t()) :: :ok
  def revoke_all_user_sessions(user, opts \\ []) do
    except = Keyword.get(opts, :except)

    delete_query = from us in Auth.UserSession, where: us.user_id == ^user.id, select: us.token

    delete_query =
      if except do
        where(delete_query, [us], us.id != ^except.id)
      else
        delete_query
      end

    {_count, tokens} = Repo.delete_all(delete_query)

    Enum.each(tokens, fn token ->
      PlausibleWeb.Endpoint.broadcast(live_socket_id(token), "disconnect", %{})
    end)
  end

  @doc """
  Sets the `logged_in` cookie share with the static site for determining
  whether client is authenticated.

  As it's a separate cookie, there's a chance it might fall out of sync
  with session cookie state due to manual deletion or premature expiration.
  """
  @spec set_logged_in_cookie(Plug.Conn.t()) :: Plug.Conn.t()
  def set_logged_in_cookie(conn) do
    Plug.Conn.put_resp_cookie(conn, "logged_in", "true",
      http_only: false,
      max_age: 60 * 60 * 24 * 365 * 5000
    )
  end

  defp get_session_by_token(token) do
    now = NaiveDateTime.utc_now(:second)

    last_team_subscription_query = Plausible.Teams.last_subscription_join_query()

    token_query =
      from(us in Auth.UserSession,
        inner_join: u in assoc(us, :user),
        as: :user,
        left_join: tm in assoc(u, :team_memberships),
        on: tm.role != :guest,
        left_join: t in assoc(tm, :team),
        as: :team,
        left_join: o in assoc(t, :owners),
        left_lateral_join: ts in subquery(last_team_subscription_query),
        on: true,
        where: us.token == ^token and us.timeout_at > ^now,
        order_by: t.id,
        preload: [user: {u, team_memberships: {tm, team: {t, subscription: ts, owners: o}}}]
      )

    case Repo.one(token_query) do
      %Auth.UserSession{} = user_session ->
        {:ok, user_session}

      nil ->
        {:error, :session_not_found}
    end
  end

  defp set_user_token(conn, token) do
    conn
    |> renew_session()
    |> TwoFactor.Session.clear_2fa_user()
    |> put_token_in_session(token)
  end

  defp login_redirect_path(conn, redirect_path) do
    if String.starts_with?(redirect_path || "", "/") do
      redirect_path
    else
      Routes.site_path(conn, :index)
    end
  end

  defp renew_session(conn) do
    Phoenix.Controller.delete_csrf_token()

    conn
    |> Plug.Conn.configure_session(renew: true)
    |> Plug.Conn.clear_session()
  end

  defp clear_logged_in_cookie(conn) do
    Plug.Conn.delete_resp_cookie(conn, "logged_in")
  end

  defp put_token_in_session(conn, token) do
    conn
    |> Plug.Conn.put_session(:user_token, token)
    |> Plug.Conn.put_session(:live_socket_id, live_socket_id(token))
  end

  defp live_socket_id(token) do
    "user_sessions:#{Base.url_encode64(token)}"
  end

  defp get_user_token(%Plug.Conn{} = conn) do
    conn
    |> Plug.Conn.get_session()
    |> get_user_token()
  end

  defp get_user_token(%{"user_token" => token}) when is_binary(token) do
    {:ok, token}
  end

  defp get_user_token(_) do
    {:error, :no_valid_token}
  end

  defp create_user_session(conn, user) do
    device_name = get_device_name(conn)

    user_session =
      user
      |> Auth.UserSession.new_session(device_name)
      |> Repo.insert!()

    {user_session.token, user_session}
  end

  defp remove_user_session(token) do
    Repo.delete_all(from us in Auth.UserSession, where: us.token == ^token)
    :ok
  end

  @unknown_label "Unknown"

  defp get_device_name(%Plug.Conn{} = conn) do
    conn
    |> Plug.Conn.get_req_header("user-agent")
    |> List.first()
    |> get_device_name()
  end

  defp get_device_name(user_agent) when is_binary(user_agent) do
    case UAInspector.parse(user_agent) do
      %UAInspector.Result{client: %UAInspector.Result.Client{name: "Headless Chrome"}} ->
        "Headless Chrome"

      %UAInspector.Result.Bot{name: name} when is_binary(name) ->
        name

      %UAInspector.Result{} = ua ->
        browser = browser_name(ua)

        if os = os_name(ua) do
          browser <> " (#{os})"
        else
          browser
        end

      _ ->
        @unknown_label
    end
  end

  defp get_device_name(_), do: @unknown_label

  defp browser_name(ua) do
    case ua.client do
      :unknown -> @unknown_label
      %UAInspector.Result.Client{name: "Mobile Safari"} -> "Safari"
      %UAInspector.Result.Client{name: "Chrome Mobile"} -> "Chrome"
      %UAInspector.Result.Client{name: "Chrome Mobile iOS"} -> "Chrome"
      %UAInspector.Result.Client{name: "Firefox Mobile"} -> "Firefox"
      %UAInspector.Result.Client{name: "Firefox Mobile iOS"} -> "Firefox"
      %UAInspector.Result.Client{name: "Opera Mobile"} -> "Opera"
      %UAInspector.Result.Client{name: "Opera Mini"} -> "Opera"
      %UAInspector.Result.Client{name: "Opera Mini iOS"} -> "Opera"
      %UAInspector.Result.Client{name: "Yandex Browser Lite"} -> "Yandex Browser"
      %UAInspector.Result.Client{name: "Chrome Webview"} -> "Mobile App"
      %UAInspector.Result.Client{type: "mobile app"} -> "Mobile App"
      client -> client.name || @unknown_label
    end
  end

  defp os_name(ua) do
    case ua.os do
      :unknown -> nil
      os -> os.name
    end
  end
end
