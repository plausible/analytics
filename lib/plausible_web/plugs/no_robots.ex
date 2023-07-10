defmodule PlausibleWeb.Plugs.NoRobots do
  @moduledoc """
  Rejects bot requests by any means available.

  We're adding `x-robots-tag` to the response header and annotate the conn
  with "noindex, nofollow" under `private.robots` key.
  In case a robot is detected anyways, we'll send 403 Forbidden.

  The only exception is, if the request is trying to access our live demo
  at plausible.io/plausible.io - in which case we'll allow indexing, but deny
  following links and skip the bot detection, in kind robots we trust.
  Note that even then, sibling URLs will be checked against bot intrusion still.
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

    conn = put_resp_header(conn, "x-robots-tag", conn.private.robots)

    if forbid?(conn) do
      conn
      |> put_resp_header("x-plausible-forbidden-reason", "robot")
      |> put_status(403)
      |> halt()
    else
      conn
    end
  end

  defp forbid?(conn) do
    with ua <- List.first(get_req_header(conn, "user-agent")),
         true <- is_binary(ua),
         "noindex" <> _ <- conn.private.robots,
         {ok, %UAInspector.Result.Bot{}} when ok in [:ok, :commit] <-
           Cachex.fetch(:user_agents, ua, &UAInspector.parse/1) do
      true
    else
      _ ->
        false
    end
  end
end
