defmodule PlausibleWeb.UserAuth do
  @moduledoc """
  Functions for user session management.
  """

  alias Plausible.Auth
  alias PlausibleWeb.TwoFactor

  alias PlausibleWeb.Router.Helpers, as: Routes

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

  @spec get_user(Plug.Conn.t() | map()) ::
          {:ok, Auth.User.t()} | {:error, :no_valid_token | :session_not_found | :user_not_found}
  def get_user(conn_or_session) do
    with {:ok, session} <- get_user_session(conn_or_session) do
      Auth.get_user_by(id: session.user_id)
    end
  end

  @spec get_user_session(Plug.Conn.t() | map()) ::
          {:ok, map()} | {:error, :no_valid_token | :session_not_found}
  def get_user_session(conn_or_session) do
    with {:ok, token} <- get_user_token(conn_or_session) do
      get_session_by_token(token)
    end
  end

  defp get_session_by_token({:legacy, user_id}) do
    {:ok, %{user_id: user_id}}
  end

  defp get_session_by_token({:new, _token}) do
    {:error, :session_not_found}
  end

  defp set_user_session(conn, user) do
    {token, _} = create_user_session(user)

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

  defp set_logged_in_cookie(conn) do
    Plug.Conn.put_resp_cookie(conn, "logged_in", "true",
      http_only: false,
      max_age: 60 * 60 * 24 * 365 * 5000
    )
  end

  defp clear_logged_in_cookie(conn) do
    Plug.Conn.delete_resp_cookie(conn, "logged_in")
  end

  defp put_token_in_session(conn, {:new, token}) do
    conn
    |> Plug.Conn.put_session(:user_token, token)
    |> Plug.Conn.put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp put_token_in_session(conn, {:legacy, user_id}) do
    Plug.Conn.put_session(conn, :current_user_id, user_id)
  end

  defp get_user_token(%Plug.Conn{} = conn) do
    conn
    |> Plug.Conn.get_session()
    |> get_user_token()
  end

  defp get_user_token(session) do
    case Enum.map(["user_token", "current_user_id"], &Map.get(session, &1)) do
      [token, nil] when is_binary(token) -> {:ok, {:new, token}}
      [nil, current_user_id] when is_integer(current_user_id) -> {:ok, {:legacy, current_user_id}}
      [nil, nil] -> {:error, :no_valid_token}
    end
  end

  defp create_user_session(user) do
    if :erlang.phash2(1, 1) == 0 do
      {{:legacy, user.id}, %{}}
    else
      {{:new, "disabled-for-now"}, %{}}
    end
  end

  defp remove_user_session(_token) do
    :ok
  end
end
