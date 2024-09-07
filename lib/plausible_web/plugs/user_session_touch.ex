defmodule PlausibleWeb.Plugs.UserSessionTouch do
  @moduledoc """
  Plug for bumping timeout on user session on every dashboard request.
  """

  import Plug.Conn

  alias PlausibleWeb.UserAuth

  def init(opts \\ []) do
    opts
  end

  def call(conn, _opts) do
    # NOTE: Needed only during transitional 14-day period
    conn = UserAuth.convert_legacy_session(conn)

    if user_session = conn.assigns[:current_user_session] do
      assign(
        conn,
        :current_user_session,
        UserAuth.touch_user_session(user_session)
      )
    else
      conn
    end
  end
end
