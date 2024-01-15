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

  @type limit() :: :site_limit | :pageview_limit | :team_member_limit

  @type over_limits_error() :: {:over_plan_limits, [limit()]}

  @type monthly_pageview_usage() :: %{period() => usage_cycle()}

  @type period :: :last_30_days | :current_cycle | :last_cycle | :penultimate_cycle

  @type usage_cycle :: %{
          date_range: Date.Range.t(),
          pageviews: non_neg_integer(),
          custom_events: non_neg_integer(),
          total: non_neg_integer()
        }

  @pageview_allowance_margin 0.1

  def pageview_allowance_margin(), do: @pageview_allowance_margin

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

  on_full_build do
    @limit_sites_since ~D[2021-05-05]
    @site_limit_for_trials 10
    @team_member_limit_for_trials 3

    @spec site_limit(User.t()) :: non_neg_integer() | :unlimited
    def site_limit(user) do
      if Timex.before?(user.inserted_at, @limit_sites_since) do
        :unlimited
      else
        get_site_limit_from_plan(user)
      end
    end

    defp get_site_limit_from_plan(user) do
      user = Plausible.Users.with_subscription(user)

      case Plans.get_subscription_plan(user.subscription) do
        %{site_limit: site_limit} -> site_limit
        :free_10k -> 50
        nil -> @site_limit_for_trials
      end
    end

    @spec team_member_limit(User.t()) :: non_neg_integer()
    def team_member_limit(user) do
      user = Plausible.Users.with_subscription(user)

      case Plans.get_subscription_plan(user.subscription) do
        %{team_member_limit: limit} -> limit
        :free_10k -> :unlimited
        nil -> @team_member_limit_for_trials
      end
    end
  else
    def site_limit(_) do
      :unlimited
    end

    def team_member_limit(_) do
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

  @doc """
  Enterprise plans are always allowed to add more sites (even when
  over limit) to avoid service disruption. Their usage is checked
  in a background job instead (see `check_usage.ex`).
  """
  def ensure_can_add_new_site(user) do
    user = Plausible.Users.with_subscription(user)

    case Plans.get_subscription_plan(user.subscription) do
      %EnterprisePlan{} ->
        :ok

      _ ->
        usage = site_usage(user)
        limit = site_limit(user)

        if below_limit?(usage, limit), do: :ok, else: {:error, {:over_limit, limit}}
    end
  end

  @monthly_pageview_limit_for_free_10k 10_000
  @monthly_pageview_limit_for_trials :unlimited

  @spec monthly_pageview_limit(User.t() | Subscription.t()) ::
          non_neg_integer() | :unlimited
  def monthly_pageview_limit(%User{} = user) do
    user = Plausible.Users.with_subscription(user)
    monthly_pageview_limit(user.subscription)
  end

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

  @doc """
  Queries the ClickHouse database for the monthly pageview usage. If the given user's
  subscription is `active`, `past_due`, or a `deleted` (but not yet expired), a map
  with the following structure is returned:

  ```elixir
  %{
    current_cycle: usage_cycle(),
    last_cycle: usage_cycle(),
    penultimate_cycle: usage_cycle()
  }
  ```

  In all other cases of the subscription status (or a `free_10k` subscription which
  does not have a `last_bill_date` defined) - the following structure is returned:

  ```elixir
  %{last_30_days: usage_cycle()}
  ```

  Given only a user as input, the usage is queried from across all the sites that the
  user owns. Alternatively, given an optional argument of `site_ids`, the usage from
  across all those sites is queried instead.
  """
  @spec monthly_pageview_usage(User.t(), list() | nil) :: monthly_pageview_usage()
  def monthly_pageview_usage(user, site_ids \\ nil)

  def monthly_pageview_usage(user, nil) do
    monthly_pageview_usage(user, Plausible.Sites.owned_site_ids(user))
  end

  def monthly_pageview_usage(user, site_ids) do
    active_subscription? = Plausible.Billing.subscription_is_active?(user.subscription)

    if active_subscription? && user.subscription.last_bill_date do
      [:current_cycle, :last_cycle, :penultimate_cycle]
      |> Task.async_stream(fn cycle ->
        %{cycle => usage_cycle(user, cycle, site_ids)}
      end)
      |> Enum.map(fn {:ok, cycle_usage} -> cycle_usage end)
      |> Enum.reduce(%{}, &Map.merge/2)
    else
      %{last_30_days: usage_cycle(user, :last_30_days, site_ids)}
    end
  end

  @spec usage_cycle(User.t(), period(), list() | nil, Date.t()) :: usage_cycle()

  def usage_cycle(user, cycle, owned_site_ids \\ nil, today \\ Timex.today())

  def usage_cycle(user, cycle, nil, today) do
    usage_cycle(user, cycle, Plausible.Sites.owned_site_ids(user), today)
  end

  def usage_cycle(_user, :last_30_days, owned_site_ids, today) do
    date_range = Date.range(Timex.shift(today, days: -30), today)

    {pageviews, custom_events} =
      Plausible.Stats.Clickhouse.usage_breakdown(owned_site_ids, date_range)

    %{
      date_range: date_range,
      pageviews: pageviews,
      custom_events: custom_events,
      total: pageviews + custom_events
    }
  end

  def usage_cycle(user, cycle, owned_site_ids, today) do
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
      Plausible.Stats.Clickhouse.usage_breakdown(owned_site_ids, date_range)

    %{
      date_range: date_range,
      pageviews: pageviews,
      custom_events: custom_events,
      total: pageviews + custom_events
    }
  end

  @spec team_member_usage(User.t()) :: integer()
  @doc """
  Returns the total count of team members associated with the user's sites.

  * The given user (i.e. the owner) is not counted as a team member.

  * Pending invitations are counted as team members even before accepted.

  * Users are counted uniquely - i.e. even if an account is associated with
    many sites owned by the given user, they still count as one team member.
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

  @doc """
  Ensures that the given user (or the usage map) is within the limits
  of the given plan.

  An `opts` argument can be passed with `ignore_pageview_limit: true`
  which bypasses the pageview limit check and returns `:ok` as long as
  the other limits are not exceeded.
  """
  @spec ensure_within_plan_limits(User.t() | map(), struct() | atom() | nil, Keyword.t()) ::
          :ok | {:error, over_limits_error()}
  def ensure_within_plan_limits(user_or_usage, plan, opts \\ [])

  def ensure_within_plan_limits(%User{} = user, %plan_mod{} = plan, opts)
      when plan_mod in [Plan, EnterprisePlan] do
    ensure_within_plan_limits(usage(user), plan, opts)
  end

  def ensure_within_plan_limits(usage, %plan_mod{} = plan, opts)
      when plan_mod in [Plan, EnterprisePlan] do
    case exceeded_limits(usage, plan, opts) do
      [] -> :ok
      exceeded_limits -> {:error, {:over_plan_limits, exceeded_limits}}
    end
  end

  def ensure_within_plan_limits(_, _, _), do: :ok

  defp exceeded_limits(usage, plan, opts) do
    for {limit, exceeded?} <- [
          {:team_member_limit, not within_limit?(usage.team_members, plan.team_member_limit)},
          {:site_limit, not within_limit?(usage.sites, plan.site_limit)},
          {:monthly_pageview_limit,
           exceeds_monthly_pageview_limit?(usage.monthly_pageviews, plan, opts)}
        ],
        exceeded? do
      limit
    end
  end

  defp exceeds_monthly_pageview_limit?(usage, plan, opts) do
    if Keyword.get(opts, :ignore_pageview_limit) do
      false
    else
      case usage do
        %{last_30_days: %{total: total}} ->
          !within_limit?(total, pageview_limit_with_margin(plan, opts))

        billing_cycles_usage ->
          Plausible.Workers.CheckUsage.exceeds_last_two_usage_cycles?(
            billing_cycles_usage,
            plan.monthly_pageview_limit
          )
      end
    end
  end

  defp pageview_limit_with_margin(%{monthly_pageview_limit: limit}, opts) do
    margin = Keyword.get(opts, :pageview_allowance_margin, @pageview_allowance_margin)
    ceil(limit * (1 + margin))
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
