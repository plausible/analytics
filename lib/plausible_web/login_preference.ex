defmodule PlausibleWeb.LoginPreference do
  @moduledoc """
  Functions for managing user login preference cookies.

  This module handles storing and retrieving the user's preferred login method
  (standard or SSO) to provide a better user experience by showing their
  preferred option first.
  """

  @cookie_name "login_preference"
  @cookie_max_age 60 * 60 * 24 * 365

  @spec set_preference(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def set_preference(conn, preference) when preference in ["standard", "sso"] do
    secure_cookie = PlausibleWeb.Endpoint.secure_cookie?()

    Plug.Conn.put_resp_cookie(conn, @cookie_name, preference,
      http_only: true,
      secure: secure_cookie,
      max_age: @cookie_max_age,
      same_site: "Lax"
    )
  end

  @spec get_preference(Plug.Conn.t()) :: String.t() | nil
  def get_preference(conn) do
    case Plug.Conn.fetch_cookies(conn) do
      %{cookies: %{@cookie_name => preference}} when preference in ["standard", "sso"] ->
        preference

      _ ->
        nil
    end
  end
end
