defmodule Plausible.CustomerSupport.Resource.Team do
  @moduledoc false
  use Plausible.CustomerSupport.Resource, component: PlausibleWeb.CustomerSupport.Live.Team

  @impl true
  def search("", limit) do
    q =
      from t in Plausible.Teams.Team,
        inner_join: o in assoc(t, :owners),
        limit: ^limit,
        where: not is_nil(t.trial_expiry_date),
        order_by: [desc: :id],
        preload: [owners: o]

    Plausible.Repo.all(q)
  end

  def search(input, limit) do
    q =
      from t in Plausible.Teams.Team,
        inner_join: o in assoc(t, :owners),
        where: ilike(t.name, ^"%#{input}%") or ilike(o.name, ^"%#{input}%"),
        limit: ^limit,
        order_by: [
          desc: fragment("?.name = ?", t, ^input),
          desc: fragment("?.name = ?", o, ^input),
          asc: t.name
        ],
        preload: [owners: o]

    Plausible.Repo.all(q)
  end

  @impl true
  def get(id) do
    Plausible.Teams.Team
    |> Repo.get(id)
    |> Plausible.Teams.with_subscription()
    |> Repo.preload(:owners)
  end
end
