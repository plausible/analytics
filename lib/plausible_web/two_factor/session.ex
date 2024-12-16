defmodule PlausibleWeb.TwoFactor.Session do
  @moduledoc """
  Functions for managing session data related to Two-Factor
  Authentication.
  """

  import Plug.Conn

  alias Plausible.Auth

  @remember_2fa_cookie "remember_2fa"
  @remember_2fa_days 30
  @remember_2fa_seconds @remember_2fa_days * 24 * 60 * 60

  @session_2fa_cookie "session_2fa"
  @session_2fa_seconds 5 * 60

  @spec set_2fa_user(Plug.Conn.t(), Auth.User.t()) :: Plug.Conn.t()
  def set_2fa_user(conn, %Auth.User{} = user) do
    put_resp_cookie(conn, @session_2fa_cookie, %{current_2fa_user_id: user.id},
      domain: domain(),
      secure: secure_cookie?(),
      encrypt: true,
      max_age: @session_2fa_seconds,
      same_site: "Lax"
    )
  end

  @spec get_2fa_user(Plug.Conn.t()) :: {:ok, Auth.User.t()} | {:error, :not_found}
  def get_2fa_user(conn) do
    conn = fetch_cookies(conn, encrypted: [@session_2fa_cookie])
    session_2fa = conn.cookies[@session_2fa_cookie]

    with id when is_integer(id) <- session_2fa[:current_2fa_user_id],
         %Auth.User{} = user <- Plausible.Repo.get(Auth.User, id) do
      {:ok, user}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec clear_2fa_user(Plug.Conn.t()) :: Plug.Conn.t()
  def clear_2fa_user(conn) do
    delete_resp_cookie(conn, @session_2fa_cookie,
      domain: domain(),
      secure: secure_cookie?(),
      encrypt: true,
      max_age: @session_2fa_seconds,
      same_site: "Lax"
    )
  end

  @spec remember_2fa_days() :: non_neg_integer()
  def remember_2fa_days(), do: @remember_2fa_days

  @spec remember_2fa?(Plug.Conn.t(), Auth.User.t()) :: boolean()
  def remember_2fa?(conn, user) do
    conn = fetch_cookies(conn, encrypted: [@remember_2fa_cookie])

    not is_nil(user.totp_token) and conn.cookies[@remember_2fa_cookie] == user.totp_token
  end

  @spec maybe_set_remember_2fa(Plug.Conn.t(), Auth.User.t(), String.t() | nil) :: Plug.Conn.t()
  def maybe_set_remember_2fa(conn, user, "true") do
    put_resp_cookie(conn, @remember_2fa_cookie, user.totp_token,
      domain: domain(),
      secure: secure_cookie?(),
      encrypt: true,
      max_age: @remember_2fa_seconds,
      same_site: "Lax"
    )
  end

  def maybe_set_remember_2fa(conn, _, _) do
    clear_remember_2fa(conn)
  end

  @spec clear_remember_2fa(Plug.Conn.t()) :: Plug.Conn.t()
  def clear_remember_2fa(conn) do
    delete_resp_cookie(conn, @remember_2fa_cookie,
      domain: domain(),
      secure: secure_cookie?(),
      encrypt: true,
      max_age: @remember_2fa_seconds,
      same_site: "Lax"
    )
  end

  defp domain(), do: PlausibleWeb.Endpoint.host()

  defp secure_cookie?() do
    :plausible
    |> Application.fetch_env!(PlausibleWeb.Endpoint)
    |> Keyword.fetch!(:secure_cookie)
  end
end
