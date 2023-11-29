defmodule Plausible.Billing.Quota do
  @moduledoc """
  This module provides functions to work with plans usage and limits.
  """

  use Plausible
  import Ecto.Query
  alias Plausible.Auth.User
  alias Plausible.Site
  alias Plausible.Billing.{Plan, Plans, Subscription, EnterprisePlan, Feature}
  alias Plausible.Billing.Feature.{Goals, RevenueGoals, Funnels, Props, StatsAPI}

  def usage(user, opts \\ []) do
    basic_usage = %{
      monthly_pageviews: monthly_pageview_usage(user),
      team_members: team_member_usage(user),
      sites: site_usage(user)
    }

    if Keyword.get(opts, :with_features) == true do
      basic_usage
      |> Map.put(:features, features_usage(user))
    else
      basic_usage
    end
  end

  @doc """
  Returns the limit of sites a user can have.

  For enterprise customers, returns :unlimited. The site limit is checked in a
  background job so as to avoid service disruption.
  """
  on_full_build do
    @limit_sites_since ~D[2021-05-05]
    @spec site_limit(User.t()) :: non_neg_integer() | :unlimited
    def site_limit(user) do
      if Timex.before?(user.inserted_at, @limit_sites_since) do
        :unlimited
      else
        get_site_limit_from_plan(user)
      end
    end

    @site_limit_for_trials 10
    @site_limit_for_legacy_trials 50
    @site_limit_for_free_10k 50
    defp get_site_limit_from_plan(user) do
      user = Plausible.Users.with_subscription(user)

      case Plans.get_subscription_plan(user.subscription) do
        %EnterprisePlan{} ->
          :unlimited

        %Plan{site_limit: site_limit} ->
          site_limit

        :free_10k ->
          @site_limit_for_free_10k

        nil ->
          if Timex.before?(user.inserted_at, Plans.business_tier_launch()) do
            @site_limit_for_legacy_trials
          else
            @site_limit_for_trials
          end
      end
    end
  else
    @spec site_limit(any()) :: non_neg_integer() | :unlimited
    def site_limit(_) do
      :unlimited
    end
  end

  @spec site_usage(User.t()) :: non_neg_integer()
  @doc """
  Returns the number of sites the given user owns.
  """
  def site_usage(user) do
    Plausible.Sites.owned_sites_count(user)
  end

  @monthly_pageview_limit_for_free_10k 10_000
  @monthly_pageview_limit_for_trials :unlimited

  @spec monthly_pageview_limit(Subscription.t()) ::
          non_neg_integer() | :unlimited
  @doc """
  Returns the limit of pageviews for a subscription.
  """
  def monthly_pageview_limit(subscription) do
    case Plans.get_subscription_plan(subscription) do
      %EnterprisePlan{monthly_pageview_limit: limit} ->
        limit

      %Plan{monthly_pageview_limit: limit} ->
        limit

      :free_10k ->
        @monthly_pageview_limit_for_free_10k

      _any ->
        if subscription do
          Sentry.capture_message("Unknown monthly pageview limit for plan",
            extra: %{paddle_plan_id: subscription.paddle_plan_id}
          )
        end

        @monthly_pageview_limit_for_trials
    end
  end

  @type monthly_pageview_usage() :: %{period() => usage_cycle()}

  @type period :: :last_30_days | :current_cycle | :last_cycle | :penultimate_cycle

  @type usage_cycle :: %{
          date_range: Date.Range.t(),
          pageviews: non_neg_integer(),
          custom_events: non_neg_integer(),
          total: non_neg_integer()
        }

  @spec monthly_pageview_usage(User.t()) :: monthly_pageview_usage()

  def monthly_pageview_usage(user) do
    active_subscription? = Plausible.Billing.subscription_is_active?(user.subscription)

    if active_subscription? && user.subscription.last_bill_date do
      [:current_cycle, :last_cycle, :penultimate_cycle]
      |> Task.async_stream(fn cycle ->
        %{cycle => usage_cycle(user, cycle)}
      end)
      |> Enum.map(fn {:ok, cycle_usage} -> cycle_usage end)
      |> Enum.reduce(%{}, &Map.merge/2)
    else
      %{last_30_days: usage_cycle(user, :last_30_days)}
    end
  end

  @spec usage_cycle(User.t(), period(), Date.t()) :: usage_cycle()

  def usage_cycle(user, cycle, today \\ Timex.today())

  def usage_cycle(user, :last_30_days, today) do
    date_range = Date.range(Timex.shift(today, days: -30), today)

    {pageviews, custom_events} =
      user
      |> Plausible.Sites.owned_site_ids()
      |> Plausible.Stats.Clickhouse.usage_breakdown(date_range)

    %{
      date_range: date_range,
      pageviews: pageviews,
      custom_events: custom_events,
      total: pageviews + custom_events
    }
  end

  def usage_cycle(user, cycle, today) do
    user = Plausible.Users.with_subscription(user)
    last_bill_date = user.subscription.last_bill_date

    normalized_last_bill_date =
      Timex.shift(last_bill_date, months: Timex.diff(today, last_bill_date, :months))

    date_range =
      case cycle do
        :current_cycle ->
          Date.range(
            normalized_last_bill_date,
            Timex.shift(normalized_last_bill_date, months: 1, days: -1)
          )

        :last_cycle ->
          Date.range(
            Timex.shift(normalized_last_bill_date, months: -1),
            Timex.shift(normalized_last_bill_date, days: -1)
          )

        :penultimate_cycle ->
          Date.range(
            Timex.shift(normalized_last_bill_date, months: -2),
            Timex.shift(normalized_last_bill_date, days: -1, months: -1)
          )
      end

    {pageviews, custom_events} =
      user
      |> Plausible.Sites.owned_site_ids()
      |> Plausible.Stats.Clickhouse.usage_breakdown(date_range)

    %{
      date_range: date_range,
      pageviews: pageviews,
      custom_events: custom_events,
      total: pageviews + custom_events
    }
  end

  @team_member_limit_for_trials 3
  @team_member_limit_for_legacy_trials :unlimited
  @spec team_member_limit(User.t()) :: non_neg_integer()
  @doc """
  Returns the limit of team members a user can have in their sites.
  """
  def team_member_limit(user) do
    user = Plausible.Users.with_subscription(user)

    case Plans.get_subscription_plan(user.subscription) do
      %EnterprisePlan{team_member_limit: limit} ->
        limit

      %Plan{team_member_limit: limit} ->
        limit

      :free_10k ->
        :unlimited

      nil ->
        if Timex.before?(user.inserted_at, Plans.business_tier_launch()) do
          @team_member_limit_for_legacy_trials
        else
          @team_member_limit_for_trials
        end
    end
  end

  @spec team_member_usage(User.t()) :: integer()
  @doc """
  Returns the total count of team members and pending invitations associated
  with the user's sites.
  """
  def team_member_usage(user) do
    Plausible.Repo.aggregate(team_member_usage_query(user), :count)
  end

  @doc false
  def team_member_usage_query(user, site \\ nil) do
    owned_sites_query = owned_sites_query(user)

    owned_sites_query =
      if site do
        where(owned_sites_query, [os], os.site_id == ^site.id)
      else
        owned_sites_query
      end

    team_members_query =
      from os in subquery(owned_sites_query),
        inner_join: sm in Site.Membership,
        on: sm.site_id == os.site_id,
        inner_join: u in assoc(sm, :user),
        where: sm.role != :owner,
        select: u.email

    from i in Plausible.Auth.Invitation,
      inner_join: os in subquery(owned_sites_query),
      on: i.site_id == os.site_id,
      where: i.role != :owner,
      select: i.email,
      union: ^team_members_query
  end

  @spec features_usage(User.t() | Site.t()) :: [atom()]
  @doc """
  Given a user, this function returns the features used across all the sites
  this user owns + StatsAPI if the user has a configured Stats API key.

  Given a site, returns the features used by the site.
  """
  def features_usage(%User{} = user) do
    props_usage_query =
      from s in Site,
        inner_join: os in subquery(owned_sites_query(user)),
        on: s.id == os.site_id,
        where: fragment("cardinality(?) > 0", s.allowed_event_props)

    revenue_goals_usage =
      from g in Plausible.Goal,
        inner_join: os in subquery(owned_sites_query(user)),
        on: g.site_id == os.site_id,
        where: not is_nil(g.currency)

    stats_api_usage = from a in Plausible.Auth.ApiKey, where: a.user_id == ^user.id

    queries =
      on_full_build do
        funnels_usage_query =
          from f in "funnels",
            inner_join: os in subquery(owned_sites_query(user)),
            on: f.site_id == os.site_id

        [
          {Props, props_usage_query},
          {Funnels, funnels_usage_query},
          {RevenueGoals, revenue_goals_usage},
          {StatsAPI, stats_api_usage}
        ]
      else
        [
          {Props, props_usage_query},
          {RevenueGoals, revenue_goals_usage},
          {StatsAPI, stats_api_usage}
        ]
      end

    Enum.reduce(queries, [], fn {feature, query}, acc ->
      if Plausible.Repo.exists?(query), do: acc ++ [feature], else: acc
    end)
  end

  def features_usage(%Site{} = site) do
    props_exist = is_list(site.allowed_event_props) && site.allowed_event_props != []

    funnels_exist =
      on_full_build do
        Plausible.Repo.exists?(from f in Plausible.Funnel, where: f.site_id == ^site.id)
      else
        false
      end

    revenue_goals_exist =
      Plausible.Repo.exists?(
        from g in Plausible.Goal, where: g.site_id == ^site.id and not is_nil(g.currency)
      )

    used_features = [
      {Props, props_exist},
      {Funnels, funnels_exist},
      {RevenueGoals, revenue_goals_exist}
    ]

    for {f_mod, used?} <- used_features, used?, f_mod.enabled?(site), do: f_mod
  end

  def ensure_can_subscribe_to_plan(user, plan, usage \\ nil)

  def ensure_can_subscribe_to_plan(%User{} = user, %Plan{} = plan, usage) do
    usage = if usage, do: usage, else: usage(user)

    case exceeded_limits(user, plan, usage) do
      [] -> :ok
      exceeded_limits -> {:error, %{exceeded_limits: exceeded_limits}}
    end
  end

  def ensure_can_subscribe_to_plan(_, _, _), do: :ok

  defp exceeded_limits(%User{} = user, %Plan{} = plan, usage) do
    for {limit, exceeded?} <- [
          {:team_member_limit, not within_limit?(usage.team_members, plan.team_member_limit)},
          {:site_limit, not within_limit?(usage.sites, plan.site_limit)},
          {:monthly_pageview_limit, exceeds_monthly_pageview_limit?(user, plan, usage)}
        ],
        exceeded? do
      limit
    end
  end

  defp exceeds_monthly_pageview_limit?(%User{allow_next_upgrade_override: true}, _, _) do
    false
  end

  defp exceeds_monthly_pageview_limit?(_user, plan, usage) do
    case usage.monthly_pageviews do
      %{last_30_days: %{total: total}} ->
        !within_limit?(total, pageview_limit_with_margin(plan))

      billing_cycles_usage ->
        Plausible.Workers.CheckUsage.exceeds_last_two_usage_cycles?(
          billing_cycles_usage,
          plan.monthly_pageview_limit
        )
    end
  end

  defp pageview_limit_with_margin(%Plan{monthly_pageview_limit: limit}) do
    allowance_margin = if limit == 10_000, do: 0.3, else: 0.15
    ceil(limit * (1 + allowance_margin))
  end

  @doc """
  Returns a list of features the user can use. Trial users have the
  ability to use all features during their trial.
  """
  def allowed_features_for(user) do
    user = Plausible.Users.with_subscription(user)

    case Plans.get_subscription_plan(user.subscription) do
      %EnterprisePlan{features: features} -> features
      %Plan{features: features} -> features
      :free_10k -> [Goals, Props, StatsAPI]
      nil -> Feature.list()
    end
  end

  defp owned_sites_query(user) do
    from sm in Site.Membership,
      where: sm.role == :owner and sm.user_id == ^user.id,
      select: %{site_id: sm.site_id}
  end

  @spec below_limit?(non_neg_integer(), non_neg_integer() | :unlimited) :: boolean()
  @doc """
  Returns whether the usage is below the limit or not.
  Returns false if usage is equal to the limit.
  """
  def below_limit?(usage, limit) do
    if limit == :unlimited, do: true, else: usage < limit
  end

  @spec within_limit?(non_neg_integer(), non_neg_integer() | :unlimited) :: boolean()
  @doc """
  Returns whether the usage is within the limit or not.
  Returns true if usage is equal to the limit.
  """
  def within_limit?(usage, limit) do
    if limit == :unlimited, do: true, else: usage <= limit
  end
end
