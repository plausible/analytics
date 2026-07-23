defmodule PlausibleWeb.Plugs.EnsureMCPEnabled do
  @moduledoc """
  Global kill switch for the MCP server and its OAuth endpoints.

  Checks the `:mcp_server` FunWithFlags flag **globally** (with no actor) so it
  can guard unauthenticated endpoints like `.well-known` metadata and the token
  endpoint. When the flag is disabled the request 404s, making the whole feature
  invisible. `PlausibleWeb.Plugs.FeatureFlagCheckPlug` is per-actor and therefore
  only usable on the logged-in consent screen, not here.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if FunWithFlags.enabled?(:mcp_server) do
      conn
    else
      conn
      |> put_status(404)
      |> Phoenix.Controller.json(%{error: "not_found"})
      |> halt()
    end
  end
end
