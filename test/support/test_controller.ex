defmodule PlausibleWeb.TestController do
  use PlausibleWeb, :controller

  def browser_basic(conn, _params) do
    send_resp(conn, 200, "ok")
  end

  def api_basic(conn, _params) do
    send_resp(conn, 200, Jason.encode!(%{"ok" => true}))
  end
end
