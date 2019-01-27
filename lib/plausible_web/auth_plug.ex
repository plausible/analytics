defmodule PlausibleWeb.AuthPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case get_session(conn, :current_user_email) do
      nil -> conn
      email ->
        user = Plausible.Auth.find_user_by(email: email)
        if user do
          assign(conn, :current_user, user)
        else
          conn
        end
    end
  end
end
