defmodule Plausible.Plugins.API.Capabilities do
  @moduledoc """
  Context module for querying API capabilities
  """
  require Plausible.Billing.Feature
  alias Plausible.Billing.Feature

  @spec get(Plug.Conn.t()) :: {:ok, map()}
  def get(conn) do
    conn = PlausibleWeb.Plugs.AuthorizePluginsAPI.call(conn, send_error?: false)

    site = conn.assigns[:authorized_site]

    features =
      if site do
        site = Plausible.Repo.preload(site, :owner)

        Feature.list()
        |> Enum.map(fn mod ->
          result = mod.check_availability(site.owner)
          feature = mod |> Module.split() |> List.last()
          {feature, result == :ok}
        end)
      else
        Enum.map(Feature.list_short_names(), &{&1, false})
      end

    {:ok,
     %{
       authorized: not is_nil(site),
       data_domain: site && site.domain,
       features: Enum.into(features, %{})
     }}
  end
end
