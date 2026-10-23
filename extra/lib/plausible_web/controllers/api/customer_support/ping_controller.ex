defmodule PlausibleWeb.Api.CustomerSupport.PingController do
  @moduledoc """
  Confirms the key works and says which user it belongs to, without changing
  anything. Used when the key is set up or replaced, and as the daily check
  that access still works.
  """
  use PlausibleWeb, :controller

  def ping(conn, _params) do
    user = conn.assigns.current_user
    json(conn, %{ok: true, user_id: user.id, email: user.email})
  end
end
