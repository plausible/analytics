defmodule Plausible.Teams.Billing do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Billing.EnterprisePlan
  alias Plausible.Billing.Plans
  alias Plausible.Billing.Subscriptions
  alias Plausible.Repo
  alias Plausible.Teams

  @team_member_limit_for_trials 3
  @limit_sites_since ~D[2021-05-05]
  @site_limit_for_trials 10

  def ensure_can_add_new_site(team) do
    team = Teams.with_subscription(team)

    case Plans.get_subscription_plan(team.subscription) do
      %EnterprisePlan{} ->
        :ok

      _ ->
        usage = site_usage(team)
        limit = site_limit(team)

        if Plausible.Billing.Quota.below_limit?(usage, limit) do
          :ok
        else
          {:error, {:over_limit, limit}}
        end
    end
  end

  def site_limit(team) do
    if Timex.before?(team.inserted_at, @limit_sites_since) do
      :unlimited
    else
      get_site_limit_from_plan(team)
    end
  end

  def site_usage(team) do
    team
    |> Teams.owned_sites()
    |> length()
  end

  defp get_site_limit_from_plan(team) do
    team = Teams.with_subscription(team)

    case Plans.get_subscription_plan(team.subscription) do
      %{site_limit: site_limit} -> site_limit
      :free_10k -> 50
      nil -> @site_limit_for_trials
    end
  end

  def team_member_limit(team) do
    team = Teams.with_subscription(team)

    case Plans.get_subscription_plan(team.subscription) do
      %{team_member_limit: limit} -> limit
      :free_10k -> :unlimited
      nil -> @team_member_limit_for_trials
    end
  end

  def quota_usage(team, opts) do
    team = Teams.with_subscription(team)
    with_features? = Keyword.get(opts, :with_features, false)
    pending_site_ids = Keyword.get(opts, :pending_ownership_site_ids, [])
    team_site_ids = team |> Teams.owned_sites() |> Enum.map(& &1.id)
    all_site_ids = pending_site_ids ++ team_site_ids

    monthly_pageviews = monthly_pageview_usage(team, all_site_ids)
    team_member_usage = team_member_usage(team, pending_ownership_site_ids: pending_site_ids)

    basic_usage = %{
      monthly_pageviews: monthly_pageviews,
      team_members: team_member_usage,
      sites: length(all_site_ids)
    }

    if with_features? do
      Map.put(basic_usage, :features, features_usage(team, all_site_ids))
    else
      basic_usage
    end
  end

  def monthly_pageview_usage(team, site_ids) do
    team = Teams.with_subscription(team)
    active_subscription? = Subscriptions.active?(team.subscription)

    if active_subscription? and team.subscription.last_bill_date != nil do
      [:current_cycle, :last_cycle, :penultimate_cycle]
      |> Task.async_stream(fn cycle ->
        {cycle, usage_cycle(team, cycle, site_ids)}
      end)
      |> Enum.into(%{}, fn {:ok, cycle_usage} -> cycle_usage end)
    else
      %{last_30_days: usage_cycle(team, :last_30_days, site_ids)}
    end
  end

  def team_member_usage(team, opts) do
    exclude_emails = Keyword.get(opts, :exclude_emails, [])
    pending_site_ids = Keyword.get(opts, :pending_ownership_site_ids, [])

    team
    |> query_team_member_emails(pending_site_ids, exclude_emails)
    |> Repo.aggregate(:count)
  end

  def usage_cycle(team, cycle, owned_site_ids \\ nil, today \\ Date.utc_today())

  def usage_cycle(team, cycle, nil, today) do
    owned_site_ids = team |> Teams.owned_sites() |> Enum.map(& &1.id)
    usage_cycle(team, cycle, owned_site_ids, today)
  end

  def usage_cycle(_team, :last_30_days, owned_site_ids, today) do
    date_range = Date.range(Date.shift(today, day: -30), today)

    {pageviews, custom_events} =
      Plausible.Stats.Clickhouse.usage_breakdown(owned_site_ids, date_range)

    %{
      date_range: date_range,
      pageviews: pageviews,
      custom_events: custom_events,
      total: pageviews + custom_events
    }
  end

  def usage_cycle(team, cycle, owned_site_ids, today) do
    team = Teams.with_subscription(team)
    last_bill_date = team.subscription.last_bill_date

    normalized_last_bill_date =
      Date.shift(last_bill_date, month: Timex.diff(today, last_bill_date, :months))

    date_range =
      case cycle do
        :current_cycle ->
          Date.range(
            normalized_last_bill_date,
            Date.shift(normalized_last_bill_date, month: 1, day: -1)
          )

        :last_cycle ->
          Date.range(
            Date.shift(normalized_last_bill_date, month: -1),
            Date.shift(normalized_last_bill_date, day: -1)
          )

        :penultimate_cycle ->
          Date.range(
            Date.shift(normalized_last_bill_date, month: -2),
            Date.shift(normalized_last_bill_date, day: -1, month: -1)
          )
      end

    {pageviews, custom_events} =
      Plausible.Stats.Clickhouse.usage_breakdown(owned_site_ids, date_range)

    %{
      date_range: date_range,
      pageviews: pageviews,
      custom_events: custom_events,
      total: pageviews + custom_events
    }
  end

  def features_usage(user, site_ids \\ nil)

  def features_usage(%Teams.Team{} = team, nil) do
    owned_site_ids = team |> Teams.owned_sites() |> Enum.map(& &1.id)
    features_usage(team, owned_site_ids)
  end

  def features_usage(%Teams.Team{} = team, owned_site_ids) when is_list(owned_site_ids) do
    site_scoped_feature_usage = features_usage(nil, owned_site_ids)

    stats_api_used? =
      from(a in Plausible.Auth.ApiKey, where: a.team_id == ^team.id)
      |> Plausible.Repo.exists?()

    if stats_api_used? do
      site_scoped_feature_usage ++ [Feature.StatsAPI]
    else
      site_scoped_feature_usage
    end
  end

  def features_usage(nil, owned_site_ids) when is_list(owned_site_ids) do
    Plausible.Billing.Quota.Usage.features_usage(nil, owned_site_ids)
  end

  defp query_team_member_emails(team, site_ids, exclude_emails) do
    pending_memberships_q =
      from tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        inner_join: gm in assoc(tm, :guest_memberships),
        where: gm.site_id in ^site_ids and tm.role != :owner,
        where: u.email not in ^exclude_emails,
        select: %{email: u.email}

    pending_invitations_q =
      from ti in Teams.Invitation,
        inner_join: gi in assoc(ti, :guest_invitations),
        where: gi.site_id in ^site_ids and ti.role != :owner,
        where: ti.email not in ^exclude_emails,
        select: %{email: ti.email}

    team_memberships_q =
      from tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        where: tm.team_id == ^team.id and tm.role != :owner,
        where: u.email not in ^exclude_emails,
        select: %{email: u.email}

    team_invitations_q =
      from ti in Teams.Invitation,
        where: ti.team_id == ^team.id and ti.role != :owner,
        where: ti.email not in ^exclude_emails,
        select: %{email: ti.email}

    pending_memberships_q
    |> union(^pending_invitations_q)
    |> union(^team_memberships_q)
    |> union(^team_invitations_q)
  end
end
