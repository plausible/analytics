defmodule Plausible.CustomerSupport.Resource.Site do
  @moduledoc false
  use Plausible.CustomerSupport.Resource, type: "site"
  alias Plausible.Repo

  @impl true
  def path(id) do
    Routes.customer_support_site_path(PlausibleWeb.Endpoint, :show, id)
  end

  @impl true
  def search(input, opts \\ [])

  def search("", opts) do
    limit = Keyword.fetch!(opts, :limit)

    q =
      from s in Plausible.Site,
        inner_join: t in assoc(s, :team),
        inner_join: o in assoc(t, :owners),
        order_by: [
          desc: :id
        ],
        limit: ^limit,
        preload: [team: {t, owners: o}]

    Repo.all(q)
  end

  def search(input, opts) do
    limit = Keyword.fetch!(opts, :limit)

    q =
      from s in Plausible.Site,
        inner_join: t in assoc(s, :team),
        inner_join: o in assoc(t, :owners),
        where:
          ilike(s.domain, ^"%#{input}%") or ilike(t.name, ^"%#{input}%") or
            ilike(o.name, ^"%#{input}%") or ilike(o.email, ^"%#{input}%"),
        order_by: [
          desc: fragment("?.domain = ?", s, ^input),
          desc: fragment("?.name = ?", t, ^input),
          desc: fragment("?.name = ?", o, ^input),
          desc: fragment("?.email = ?", o, ^input),
          asc: s.domain
        ],
        limit: ^limit,
        preload: [team: {t, owners: o}]

    Repo.all(q)
  end

  @impl true
  def get(id) do
    Plausible.Site
    |> Repo.get!(id)
    |> Repo.preload(:team)
  end
end
