defmodule Plausible.ConsolidatedView do
  def create_for_team(%Plausible.Teams.Team{} = team) do
    Plausible.Site.new_consolidated_for_team(team)
    |> Plausible.Repo.insert()
  end

  def get_for_team(%Plausible.Teams.Team{} = team) do
    Plausible.Repo.get_by(Plausible.Site, domain: "cv-#{team.identifier}")
  end

  def get_site_ids(%Plausible.Site{consolidated: true} = site) do
    Plausible.Cache.Adapter.get(:site_ids, site.id, fn ->
      Plausible.Teams.owned_sites_ids(site.team)
    end)
  end

  def get_site_ids(%Plausible.Site{consolidated: false}), do: nil
end
