defmodule Plausible.CustomerSupport.Resource.User do
  use Plausible.CustomerSupport.Resource, component: PlausibleWeb.CustomerSupport.Live.User

  @impl true
  def get(id) do
    Plausible.Repo.get!(Plausible.Auth.User, id)
    |> Plausible.Repo.preload(owned_teams: :sites)
  end

  @impl true
  def search(input) do
    q =
      from u in Plausible.Auth.User,
        where: ilike(u.email, ^"%#{input}%") or ilike(u.name, ^"%#{input}%"),
        order_by: fragment("CASE WHEN email = ? OR name = ? THEN 0 ELSE 1 END", ^input, ^input),
        preload: [:owned_teams],
        limit: 10

    Plausible.Repo.all(q)
  end
end
