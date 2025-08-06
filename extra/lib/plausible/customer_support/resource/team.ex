defmodule Plausible.CustomerSupport.Resource.Team do
  @moduledoc false
  use Plausible.CustomerSupport.Resource, type: "team"
  alias Plausible.Teams
  alias Plausible.Repo

  @impl true
  def path(id) do
    Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, id)
  end

  @impl true
  def search(input, opts \\ [])

  def search("", opts) do
    limit = Keyword.fetch!(opts, :limit)

    q =
      from t in Plausible.Teams.Team,
        as: :team,
        inner_join: o in assoc(t, :owners),
        limit: ^limit,
        where: not is_nil(t.trial_expiry_date),
        left_lateral_join: s in subquery(Teams.last_subscription_join_query()),
        on: true,
        order_by: [desc: :id],
        preload: [owners: o, subscription: s]

    Plausible.Repo.all(q)
  end

  def search(input, opts) do
    limit = Keyword.fetch!(opts, :limit)

    q =
      from t in Plausible.Teams.Team,
        as: :team,
        inner_join: o in assoc(t, :owners),
        where:
          ilike(t.name, ^"%#{input}%") or ilike(o.name, ^"%#{input}%") or
            ilike(o.email, ^"%#{input}%"),
        limit: ^limit,
        order_by: [
          desc: fragment("?.name = ?", t, ^input),
          desc: fragment("?.name = ?", o, ^input),
          desc: fragment("?.email = ?", o, ^input),
          asc: t.name
        ],
        preload: [owners: o]

    q =
      if opts[:with_subscription_only?] do
        from t in q,
          inner_lateral_join: s in subquery(Teams.last_subscription_join_query()),
          on: true,
          preload: [subscription: s]
      else
        from t in q,
          left_lateral_join: s in subquery(Teams.last_subscription_join_query()),
          on: true,
          preload: [subscription: s]
      end

    q =
      if opts[:with_sso_only?] do
        from t in q,
          inner_join: sso_integration in assoc(t, :sso_integration),
          as: :sso_integration,
          left_join: sso_domains in assoc(sso_integration, :sso_domains),
          as: :sso_domains,
          or_where: ilike(sso_domains.domain, ^"%#{input}%")
      else
        q
      end

    Plausible.Repo.all(q)
  end

  @impl true
  def get(id) do
    Plausible.Teams.Team
    |> Repo.get!(id)
    |> Plausible.Teams.with_subscription()
    |> Repo.preload(:owners)
  end
end
