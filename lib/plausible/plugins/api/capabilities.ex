defmodule Plausible.Plugins.API.Capabilities do
  @moduledoc """
  Context module for querying API capabilities
  """
  require Plausible.Billing.Feature

  @spec get(Plug.Conn.t()) :: {:ok, map()}
  def get(conn) do
    conn = PlausibleWeb.Plugs.AuthorizePluginsAPI.call(conn, send_resp?: false)

    site = conn.assigns[:authorized_site]

    features =
      if site do
        Plausible.Billing.Feature.list()
        |> Enum.map(fn mod ->
          site = Plausible.Repo.preload(site, :owner)
          result = mod.check_availability(site.owner)
          feature = Module.split(mod) |> List.last()

          if result == :ok do
            {feature, true}
          else
            {feature, false}
          end
        end)
      else
        Plausible.Billing.Feature.list_short_names()
        |> Enum.map(&{&1, false})
      end

    {:ok,
     %{
       authorized: not is_nil(site),
       data_domain: site && site.domain,
       features: Enum.into(features, %{})
     }}
  end
end
