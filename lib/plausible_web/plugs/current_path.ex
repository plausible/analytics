defmodule PlausibleWeb.Plugs.CurrentPath do
  @moduledoc false

  def init(_), do: []
  def call(conn, _), do: Plug.Conn.assign(conn, :current_path, Path.join(conn.path_info))
end
