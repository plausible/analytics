defmodule PlausibleWeb.Plugs.UserSessionTouch do
  @moduledoc """
  Plug for bumping timeout on user session on every dashboard request.
  """

  import Plug.Conn

  alias Plausible.Auth

  def init(opts \\ []) do
    opts
  end

  def call(conn, _opts) do
    if user_session = conn.assigns[:current_user_session] do
      assign(
        conn,
        :current_user_session,
        Auth.UserSessions.touch(user_session)
      )
    else
      conn
    end
  end
end
