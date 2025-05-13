defmodule Plausible.CustomerSupport.Resource.User do
  @moduledoc false
  use Plausible.CustomerSupport.Resource, component: PlausibleWeb.CustomerSupport.Live.User

  @impl true
  def get(id) do
    Plausible.Repo.get!(Plausible.Auth.User, id)
    |> Plausible.Repo.preload(team_memberships: :team)
  end

  @impl true
  def search("", limit) do
    q =
      from u in Plausible.Auth.User,
        order_by: [
          desc: :id
        ],
        preload: [:owned_teams],
        limit: ^limit

    Plausible.Repo.all(q)
  end

  def search(input, limit) do
    q =
      from u in Plausible.Auth.User,
        where: ilike(u.email, ^"%#{input}%") or ilike(u.name, ^"%#{input}%"),
        order_by: [
          desc: fragment("?.name = ?", u, ^input),
          desc: fragment("?.email = ?", u, ^input),
          asc: u.name
        ],
        preload: [:owned_teams],
        limit: ^limit

    Plausible.Repo.all(q)
  end
end
