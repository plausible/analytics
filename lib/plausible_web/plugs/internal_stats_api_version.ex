defmodule PlausibleWeb.Plugs.InternalStatsApiVersion do
  @moduledoc """
  A plug that adds the `x-api-version` response header. The goal is to make
  it easier to deploy changes to the dashboard where the previous FE state
  is incompatible with the new BE (e.g. removing a stats endpoint, because
  the new FE switches to a new one). Increment it manually when introducing
  such changes, so that the frontend could detect the version mismatch and
  trigger a page reload.
  """
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @api_version "0"

  def api_version, do: @api_version

  @impl true
  def call(conn, _opts \\ nil) do
    put_resp_header(conn, "x-api-version", @api_version)
  end
end
