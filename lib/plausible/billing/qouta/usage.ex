defmodule Plausible.Billing.Quota.Usage do
  @moduledoc false

  use Plausible
  import Ecto.Query
  alias Plausible.Auth.User
  alias Plausible.Site
  alias Plausible.Billing.Feature

  def query_team_member_emails(site_ids) do
    memberships_q =
      from sm in Site.Membership,
        where: sm.site_id in ^site_ids,
        inner_join: u in assoc(sm, :user),
        select: %{email: u.email}

    invitations_q =
      from i in Plausible.Auth.Invitation,
        where: i.site_id in ^site_ids and i.role != :owner,
        select: %{email: i.email}

    union(memberships_q, ^invitations_q)
  end

  def features_usage(user, site_ids \\ nil)

  def features_usage(%User{} = user, nil) do
    site_ids = Plausible.Sites.owned_site_ids(user)
    features_usage(user, site_ids)
  end

  def features_usage(%User{} = user, site_ids) when is_list(site_ids) do
    site_scoped_feature_usage = features_usage(nil, site_ids)

    stats_api_used? =
      from(a in Plausible.Auth.ApiKey, where: a.user_id == ^user.id)
      |> Plausible.Repo.exists?()

    if stats_api_used? do
      site_scoped_feature_usage ++ [Feature.StatsAPI]
    else
      site_scoped_feature_usage
    end
  end

  def features_usage(nil, site_ids) when is_list(site_ids) do
    props_usage_q =
      from s in Site,
        where: s.id in ^site_ids and fragment("cardinality(?) > 0", s.allowed_event_props)

    revenue_goals_usage_q =
      from g in Plausible.Goal,
        where: g.site_id in ^site_ids and not is_nil(g.currency)

    queries =
      on_ee do
        funnels_usage_q = from f in "funnels", where: f.site_id in ^site_ids

        [
          {Feature.Props, props_usage_q},
          {Feature.Funnels, funnels_usage_q},
          {Feature.RevenueGoals, revenue_goals_usage_q}
        ]
      else
        [
          {Feature.Props, props_usage_q},
          {Feature.RevenueGoals, revenue_goals_usage_q}
        ]
      end

    Enum.reduce(queries, [], fn {feature, query}, acc ->
      if Plausible.Repo.exists?(query), do: acc ++ [feature], else: acc
    end)
  end
end
