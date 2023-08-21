defmodule PlausibleWeb.Plugs.RuntimeSessionAdapter do
  @moduledoc """
  A `Plug.Session` adapter that allows configuration at runtime.
  Sadly, the plug being wrapped has no MFA option for dynamic
  configuration.

  This is currently used so we can dynamically pass the :domain
  and have cookies planted across one root domain.
  """

  @behaviour Plug

  @impl true
  def init(opts) do
    Plug.Session.init(opts)
  end

  @impl true
  def call(conn, opts) do
    Plug.Session.call(conn, patch_cookie_domain(opts))
  end

  defp patch_cookie_domain(%{cookie_opts: cookie_opts} = runtime_opts) do
    Map.replace(
      runtime_opts,
      :cookie_opts,
      Keyword.put_new(cookie_opts, :domain, PlausibleWeb.Endpoint.host())
    )
  end
end
