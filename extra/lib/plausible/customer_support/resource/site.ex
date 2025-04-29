defmodule Plausible.CustomerSupport.Resource.Site do
  use Plausible.CustomerSupport.Resource, component: PlausibleWeb.CustomerSupport.Live.Site

  @impl true
  def search(input, limit) do
    q =
      from s in Plausible.Site,
        inner_join: t in assoc(s, :team),
        inner_join: o in assoc(t, :owners),
        where:
          ilike(s.domain, ^"%#{input}%") or ilike(t.name, ^"%#{input}%") or
            ilike(o.name, ^"%#{input}%"),
        order_by: [
          desc: fragment("?.domain = ?", s, ^input),
          desc: fragment("?.name = ?", t, ^input),
          desc: fragment("?.name = ?", o, ^input),
          asc: s.domain
        ],
        limit: ^limit,
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
