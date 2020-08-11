defmodule PlausibleWeb.Firewall do
  import Plug.Conn

  def init(options) do
    blocklist = Keyword.fetch!(Application.get_env(:plausible, __MODULE__), :blocklist)
    |> String.split(",")
    |> Enum.map(&String.trim/1)

    Keyword.merge(options, blocklist: blocklist)
  end

  def call(conn, opts) do
    if PlausibleWeb.RemoteIp.get(conn) in opts[:blocklist] do
      send_resp(conn, 404, "Not found") |> halt
    else
      conn
    end
  end
end
