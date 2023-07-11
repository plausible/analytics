defmodule PlausibleWeb.Plugs.NoRobots do
  @moduledoc """
  Rejects bot requests by any means available.

  We're adding `x-robots-tag` to the response header and annotate the conn
  with "noindex, nofollow" under `private.robots` key.

  The only exception is, if the request is trying to access our live demo
  at plausible.io/plausible.io - in which case we'll allow indexing, but deny
  following links and skip the bot detection, in kind robots we trust.
  """
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts \\ nil) do
    conn =
      if conn.path_info == ["plausible.io"] do
        put_private(conn, :robots, "index, nofollow")
      else
        put_private(conn, :robots, "noindex, nofollow")
      end

    put_resp_header(conn, "x-robots-tag", conn.private.robots)
  end
end
