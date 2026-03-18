defmodule PlausibleWeb.Plugs.CurrentPath do
  @moduledoc false

  def init(_), do: []
  def call(conn, _), do: Plug.Conn.assign(conn, :current_path, conn.request_path)
end
