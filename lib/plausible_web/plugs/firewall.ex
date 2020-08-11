defmodule PlausibleWeb.Firewall do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    blocklist = Keyword.fetch!(Application.get_env(:plausible, __MODULE__), :blocklist)
    if PlausibleWeb.RemoteIp.get(conn) in blocklist do
      send_resp(conn, 404, "Not found") |> halt
    else
      conn
    end
  end
end
