defmodule Plausible.CustomerSupport.Resource.Site do
  use Plausible.CustomerSupport.Resource, component: PlausibleWeb.CustomerSupport.Live.Site

  @impl true
  def search(input) do
    q =
      from s in Plausible.Site,
        inner_join: t in assoc(s, :team),
        inner_join: o in assoc(t, :owners),
        or_where: ilike(s.domain, ^"%#{input}%"),
        or_where: ilike(t.name, ^"%#{input}%"),
        or_where: ilike(o.name, ^"%#{input}%"),
        limit: 10,
        preload: [team: {t, owners: o}]

    Plausible.Repo.all(q)
  end

  @impl true
  def get(id) do
    Plausible.Site
    |> Plausible.Repo.get(id)
    |> Plausible.Repo.preload(:team)
  end
end
