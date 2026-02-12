defmodule Plausible.Billing.Quota do
  @moduledoc """
  This module provides functions to work with plans usage and limits.
  """

  use Plausible
  alias Plausible.Billing.{EnterprisePlan, Plan}
  alias Plausible.Billing.Quota.Limits

  @type cycle() :: :current_cycle | :last_cycle | :penultimate_cycle

  @type cycles_usage() :: %{cycle() => usage_cycle()}

  @type usage_cycle() :: %{
          date_range: Date.Range.t(),
          pageviews: non_neg_integer(),
          custom_events: non_neg_integer(),
          total: non_neg_integer()
        }

  @doc """
  Ensures that the given usage map is within the limits
  of the given plan.

  An `opts` argument can be passed with `ignore_pageview_limit: true`
  which bypasses the pageview limit check and returns `:ok` as long as
  the other limits are not exceeded.
  """
  @spec ensure_within_plan_limits(map(), struct() | atom() | nil, Keyword.t()) ::
          :ok | {:error, Limits.over_limits_error()}

  def ensure_within_plan_limits(usage, plan_mod, opts \\ [])

  def ensure_within_plan_limits(usage, %plan_mod{} = plan, opts)
      when plan_mod in [Plan, EnterprisePlan] do
    case exceeded_limits(usage, plan, opts) do
      [] -> :ok
      exceeded_limits -> {:error, {:over_plan_limits, exceeded_limits}}
    end
  end

  def ensure_within_plan_limits(_, _, _), do: :ok

  def eligible_for_upgrade?(usage), do: usage.sites > 0

  def ensure_feature_access(usage, plan) do
    case usage.features -- plan.features do
      [] -> :ok
      features -> {:error, {:unavailable_features, features}}
    end
  end

  @doc """
  Suggests a suitable tier (Starter, Growth or Business) for the given usage map.

  If even the highest Business plan does not accommodate the usage, then
  `:custom` is returned. This means that this kind of usage should get on
  a custom plan.

  To avoid confusion, we do not recommend a lower tier for customers that
  are already on a higher tier (even if their usage is low enough).

  `nil` is returned if the usage is not eligible for upgrade.
  """
  def suggest_tier(usage, highest_starter, highest_growth, highest_business, owned_tier) do
    cond do
      not eligible_for_upgrade?(usage) ->
        nil

      not is_nil(highest_starter) and usage_fits_plan?(usage, highest_starter) and
          owned_tier not in [:business, :growth] ->
        :starter

      usage_fits_plan?(usage, highest_growth) and owned_tier != :business ->
        :growth

      usage_fits_plan?(usage, highest_business) ->
        :business

      true ->
        :custom
    end
  end

  defp usage_fits_plan?(usage, plan) do
    with :ok <- ensure_within_plan_limits(usage, plan),
         :ok <- ensure_feature_access(usage, plan) do
      true
    else
      _ -> false
    end
  end

  defp exceeded_limits(usage, plan, opts) do
    site_limit_exceeded? =
      if opts[:skip_site_limit_check?] do
        false
      else
        not within_limit?(usage.sites, plan.site_limit)
      end

    for {limit, exceeded?} <- [
          {:team_member_limit, not within_limit?(usage.team_members, plan.team_member_limit)},
          {:site_limit, site_limit_exceeded?},
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
      if has_billing_cycles?(usage) do
        exceeds_last_two_usage_cycles?(usage, plan.monthly_pageview_limit)
      else
        margin = Keyword.get(opts, :pageview_allowance_margin)
        limit = Limits.pageview_limit_with_margin(plan.monthly_pageview_limit, margin)
        !within_limit?(usage.last_30_days.total, limit)
      end
    end
  end

  @spec exceeds_last_two_usage_cycles?(cycles_usage(), non_neg_integer()) ::
          boolean()
  def exceeds_last_two_usage_cycles?(cycles_usage, allowed_volume) do
    exceeded = exceeded_cycles(cycles_usage, allowed_volume)
    :penultimate_cycle in exceeded && :last_cycle in exceeded
  end

  @spec exceeded_cycles(cycles_usage(), non_neg_integer()) :: list()
  def exceeded_cycles(cycles_usage, allowed_volume) do
    limit = Limits.pageview_limit_with_margin(allowed_volume)

    Enum.reduce(cycles_usage, [], fn {cycle, %{total: total}}, exceeded_cycles ->
      if below_limit?(total, limit) do
        exceeded_cycles
      else
        exceeded_cycles ++ [cycle]
      end
    end)
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

  @doc """
  Returns whether the usage has billing cycle data.
  """
  def has_billing_cycles?(usage) do
    not is_map_key(usage, :last_30_days)
  end

  @doc """
  Determines which notification type should be shown based on current usage and limits.

  Returns an atom representing the notification type, or nil if no notification should be shown.

  ## Pageview limit enforcement

  Pageview limit notifications use different thresholds for warnings vs enforcement:

  - Warning notifications (approaching, exceeded): Check against base limit (e.g., 10k)
    to notify users when they exceed their purchased plan allowance
  - Enforcement (grace period & locking): The background job checks limit with 10% margin
    (e.g., 11k) and starts a 7-day grace period when both cycles exceed this threshold. After
    the grace period expires, dashboard access is locked.

  Example for 10k plan:
  - 9,000 pageviews: `:pageview_approaching_limit` (90% of base limit)
  - 10,500 pageviews (1 cycle): `:traffic_exceeded_last_cycle` (over base limit)
  - 10,500 + 10,200 pageviews: `:traffic_exceeded_sustained` (both cycles over base limit)
  - 12,000 + 11,500 pageviews + grace period active: `:grace_period_active` (over margin)
  - 12,000 + 11,500 pageviews + grace period expired: `:dashboard_locked` (over margin)

  ## Priority order

  1. Dashboard locked
  2. Trial ended
  3. Grace period active
  4. Traffic exceeded for 2 consecutive cycles
  5. Traffic exceeded for 1 cycle
  6. Pageview limit approaching
  7. Site and team member limits both reached
  8. Site limit reached
  9. Team member limit reached
  """
  def usage_notification_type(team, usage) do
    subscription = Plausible.Teams.Billing.get_subscription(team)
    pageview_limit = Plausible.Teams.Billing.monthly_pageview_limit(subscription)
    site_limit = Plausible.Teams.Billing.site_limit(team)
    team_member_limit = Plausible.Teams.Billing.team_member_limit(team)

    pageview_usage = usage.monthly_pageviews
    site_usage = usage.sites
    team_member_usage = usage.team_members

    pageview_notification =
      if not Plausible.Teams.on_trial?(team) and has_billing_cycles?(pageview_usage) do
        pageview_cycle_usage_notification_type(pageview_usage, pageview_limit)
      end

    cond do
      Plausible.Teams.GracePeriod.expired?(team) ->
        :dashboard_locked

      not Plausible.Teams.on_trial?(team) and is_nil(subscription) ->
        :trial_ended

      Plausible.Teams.GracePeriod.active?(team) ->
        :grace_period_active

      pageview_notification ->
        pageview_notification

      site_usage >= site_limit and site_limit != :unlimited and
        team_member_usage >= team_member_limit and team_member_limit != :unlimited ->
        :site_and_team_member_limit_reached

      site_usage >= site_limit and site_limit != :unlimited ->
        :site_limit_reached

      team_member_usage >= team_member_limit and team_member_limit != :unlimited ->
        :team_member_limit_reached

      true ->
        nil
    end
  end

  defp pageview_cycle_usage_notification_type(usage, limit) do
    last_exceeded? = is_map_key(usage, :last_cycle) and usage.last_cycle.total > limit

    penultimate_exceeded? =
      is_map_key(usage, :penultimate_cycle) and usage.penultimate_cycle.total > limit

    cond do
      last_exceeded? and penultimate_exceeded? ->
        :traffic_exceeded_sustained

      last_exceeded? ->
        :traffic_exceeded_last_cycle

      is_map_key(usage, :current_cycle) and usage.current_cycle.total >= limit * 0.9 ->
        :pageview_approaching_limit

      true ->
        nil
    end
  end
end
