defmodule PlausibleWeb.Plugs.InternalStatsApiVersion do
  @moduledoc """
  Adds the `x-api-version` response header to all internal
  stats API responses. See `Plausible.InternalStatsApiVersion`
  for version tracking and rollout logic.
  """
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    version = Plausible.InternalStatsApiVersion.effective_version()
    put_resp_header(conn, "x-api-version", to_string(version))
  end
end
