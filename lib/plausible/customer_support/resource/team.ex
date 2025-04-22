defmodule Plausible.CustomerSupport.Resource.Team do

  use Plausible.CustomerSupport.Resource, component: PlausibleWeb.CustomerSupport.Live.Team

  @impl true
  def search(input) do
    q =
      from t in Plausible.Teams.Team,
        inner_join: o in assoc(t, :owners),
        or_where: ilike(t.name, ^"%#{input}%"),
        or_where: ilike(o.name, ^"%#{input}%"),
        limit: 10,
        preload: [owners: o]

    Plausible.Repo.all(q)
  end

@impl true
  def get(id) do
    Plausible.Teams.Team
    |> Repo.get(id)
    |> Repo.preload(:owners)
  end
end
