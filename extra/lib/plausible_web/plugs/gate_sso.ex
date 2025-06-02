defmodule PlausibleWeb.Plugs.GateSSO do
  @moduledoc """
  Plug for gating access to SSO routes with `SSO_ENABLED` env var.
  """

  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _) do
    if Plausible.sso_enabled?() do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    end
  end
end
