defmodule PlausibleWeb.UserAuth do
  @moduledoc """
  Functions for user session management.

  In it's current shape, both current (legacy) and soon to be implemented (new)
  user sessions are supported side by side.

  The legacy token is still accepted from the session cookie. Once 14 days
  pass (the current time window for which session cookie is valid without
  any activity), the legacy cookies won't be accepted anymore (legacy token
  retrieval is tracked with logging) and the logic will be cleaned of branching
  for legacy session.
  """

  import Ecto.Query, only: [from: 2]

  alias Plausible.Auth
  alias Plausible.Repo
  alias PlausibleWeb.TwoFactor

  alias PlausibleWeb.Router.Helpers, as: Routes

  require Logger

  @spec log_in_user(Plug.Conn.t(), Auth.User.t(), String.t() | nil) :: Plug.Conn.t()
  def log_in_user(conn, user, redirect_path \\ nil) do
    login_dest =
      redirect_path || Plug.Conn.get_session(conn, :login_dest) || Routes.site_path(conn, :index)

    conn
    |> set_user_session(user)
    |> set_logged_in_cookie()
    |> Phoenix.Controller.redirect(external: login_dest)
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

  @spec touch_user_session(Auth.UserSession.t()) :: Auth.UserSession.t()
  def touch_user_session(%{token: nil} = user_session) do
    # NOTE: Legacy token sessions can't be touched.
    user_session
  end

  def touch_user_session(user_session, now \\ NaiveDateTime.utc_now(:second)) do
    if NaiveDateTime.diff(now, user_session.last_used_at, :hour) >= 1 do
      Plausible.Users.bump_last_seen(user_session.user_id, now)

      user_session
      |> Auth.UserSession.touch_session(now)
      |> Repo.update!(allow_stale: true)
    else
      user_session
    end
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

  @spec convert_legacy_session(Plug.Conn.t()) :: Plug.Conn.t()
  def convert_legacy_session(conn) do
    current_user = conn.assigns[:current_user]

    if current_user && Plug.Conn.get_session(conn, :current_user_id) do
      {token, user_session} = create_user_session(conn, current_user)

      conn
      |> put_token_in_session(token)
      |> Plug.Conn.delete_session(:current_user_id)
      |> Plug.Conn.assign(:current_user_session, user_session)
    else
      conn
    end
  end

  defp get_session_by_token({:legacy, user_id}) do
    case Plausible.Users.with_subscription(user_id) do
      %Auth.User{} = user ->
        {:ok, %Auth.UserSession{user_id: user.id, user: user}}

      nil ->
        {:error, :session_not_found}
    end
  end

  defp get_session_by_token({:new, token}) do
    now = NaiveDateTime.utc_now(:second)

    last_subscription_query = Plausible.Users.last_subscription_join_query()

    token_query =
      from(us in Auth.UserSession,
        inner_join: u in assoc(us, :user),
        as: :user,
        left_lateral_join: s in subquery(last_subscription_query),
        on: true,
        where: us.token == ^token and us.timeout_at > ^now,
        preload: [user: {u, subscription: s}]
      )

    case Repo.one(token_query) do
      %Auth.UserSession{} = user_session ->
        {:ok, user_session}

      nil ->
        {:error, :session_not_found}
    end
  end

  defp set_user_session(conn, user) do
    {token, _} = create_user_session(conn, user)

    conn
    |> renew_session()
    |> TwoFactor.Session.clear_2fa_user()
    |> put_token_in_session(token)
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

  defp put_token_in_session(conn, {:new, token}) do
    conn
    |> Plug.Conn.put_session(:user_token, token)
    |> Plug.Conn.put_session(:live_socket_id, "user_sessions:#{Base.url_encode64(token)}")
  end

  defp get_user_token(%Plug.Conn{} = conn) do
    conn
    |> Plug.Conn.get_session()
    |> get_user_token()
  end

  defp get_user_token(%{"user_token" => token}) when is_binary(token) do
    {:ok, {:new, token}}
  end

  defp get_user_token(%{"current_user_id" => user_id}) when is_integer(user_id) do
    Logger.warning("Legacy user session detected (user: #{user_id})")
    {:ok, {:legacy, user_id}}
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

    {{:new, user_session.token}, user_session}
  end

  defp remove_user_session({:legacy, _}), do: :ok

  defp remove_user_session({:new, token}) do
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
