defmodule Plausible.CustomerSupport.Resource.User do
  @moduledoc false
  use Plausible.CustomerSupport.Resource
  alias Plausible.Repo

  @impl true
  def get(id) do
    Repo.get!(Plausible.Auth.User, id)
    |> Repo.preload(team_memberships: :team)
  end

  @impl true
  def search(input, opts \\ [])

  def search("", opts) do
    limit = Keyword.fetch!(opts, :limit)

    q =
      from u in Plausible.Auth.User,
        order_by: [
          desc: :id
        ],
        preload: [:owned_teams],
        limit: ^limit

    Repo.all(q)
  end

  def search(input, opts) do
    limit = Keyword.fetch!(opts, :limit)

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

    Repo.all(q)
  end
end
