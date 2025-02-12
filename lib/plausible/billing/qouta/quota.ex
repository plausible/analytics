defmodule Plausible.Billing.Quota do
  @moduledoc """
  This module provides functions to work with plans usage and limits.
  """

  use Plausible
  alias Plausible.Billing.{Plan, EnterprisePlan}
  alias Plausible.Billing.Quota.Limits

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
  Suggests a suitable tier (Growth or Business) for the given usage map.

  If even the highest Business plan does not accommodate the usage, then
  `:custom` is returned. This means that this kind of usage should get on
  a custom plan.

  `nil` is returned if the usage is not eligible for upgrade.
  """
  def suggest_tier(usage, highest_growth_plan, highest_business_plan) do
    if eligible_for_upgrade?(usage) do
      cond do
        usage_fits_plan?(usage, highest_growth_plan) -> :growth
        usage_fits_plan?(usage, highest_business_plan) -> :business
        true -> :custom
      end
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
      case usage do
        %{last_30_days: %{total: total}} ->
          margin = Keyword.get(opts, :pageview_allowance_margin)
          limit = Limits.pageview_limit_with_margin(plan.monthly_pageview_limit, margin)
          !within_limit?(total, limit)

        cycles_usage ->
          exceeds_last_two_usage_cycles?(cycles_usage, plan.monthly_pageview_limit)
      end
    end
  end

  @spec exceeds_last_two_usage_cycles?(Plausible.Teams.Billing.cycles_usage(), non_neg_integer()) ::
          boolean()
  def exceeds_last_two_usage_cycles?(cycles_usage, allowed_volume) do
    exceeded = exceeded_cycles(cycles_usage, allowed_volume)
    :penultimate_cycle in exceeded && :last_cycle in exceeded
  end

  @spec exceeded_cycles(Plausible.Teams.Billing.cycles_usage(), non_neg_integer()) :: list()
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
end
