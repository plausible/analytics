defmodule Plausible.ConsolidatedView do
  def get_site_ids(%Plausible.Site{consolidated: true} = site) do
    Plausible.Cache.Adapter.get(:site_ids, site.id, fn ->
      Plausible.Teams.owned_sites_ids(site.team)
    end)
  end

  def get_site_ids(%Plausible.Site{consolidated: false}), do: nil
end
