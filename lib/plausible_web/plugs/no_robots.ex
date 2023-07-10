defmodule PlausibleWeb.Plugs.NoRobots do
  @moduledoc """
  Rejects bot requests by any means available.
  """
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts \\ nil) do
    conn = put_resp_header(conn, "x-robots-tag", "noindex, nofollow")

    if bot?(conn) do
      conn
      |> put_resp_header("x-plausible-forbidden-reason", "robot")
      |> put_status(403)
      |> halt()
    else
      conn
    end
  end

  defp bot?(conn) do
    with ua <- List.first(get_req_header(conn, "user-agent")),
         true <- is_binary(ua),
         {ok, %UAInspector.Result.Bot{}} when ok in [:ok, :commit] <-
           Cachex.fetch(:user_agents, ua, &UAInspector.parse/1) do
      true
    else
      _ ->
        false
    end
  end
end
