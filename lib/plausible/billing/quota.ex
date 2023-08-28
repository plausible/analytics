defmodule Plausible.Billing.Quota do
  @moduledoc """
  This module provides functions to work with plans usage and limits.
  """

  alias Plausible.Billing.Plans

  @limit_sites_since ~D[2021-05-05]
  @spec site_limit(Plausible.Auth.User.t()) :: non_neg_integer() | :unlimited
  @doc """
  Returns the limit of sites a user can have.

  For enterprise customers, returns :unlimited. The site limit is checked in a
  background job so as to avoid service disruption.
  """
  def site_limit(user) do
    cond do
      Application.get_env(:plausible, :is_selfhost) -> :unlimited
      Timex.before?(user.inserted_at, @limit_sites_since) -> :unlimited
      true -> get_site_limit_from_plan(user)
    end
  end

  @site_limit_for_trials 50
  @site_limit_for_free_10k 50
  defp get_site_limit_from_plan(user) do
    user = Plausible.Users.with_subscription(user)

    case Plans.get_subscription_plan(user.subscription) do
      %Plausible.Billing.EnterprisePlan{} -> :unlimited
      %Plausible.Billing.Plan{site_limit: site_limit} -> site_limit
      :free_10k -> @site_limit_for_free_10k
      nil -> @site_limit_for_trials
    end
  end

  @spec site_usage(Plausible.Auth.User.t()) :: non_neg_integer()
  @doc """
  Returns the number of sites the given user owns.
  """
  def site_usage(user) do
    Plausible.Sites.owned_sites_count(user)
  end

  @monthly_pageview_limit_for_free_10k 10_000

  @spec monthly_pageview_limit(Plausible.Billing.Subscription.t()) ::
          non_neg_integer() | :unlimited
  @doc """
  Returns the limit of pageviews for a subscription.
  """
  def monthly_pageview_limit(subscription) do
    case Plans.get_subscription_plan(subscription) do
      %Plausible.Billing.EnterprisePlan{monthly_pageview_limit: limit} ->
        limit

      %Plausible.Billing.Plan{monthly_pageview_limit: limit} ->
        limit

      :free_10k ->
        @monthly_pageview_limit_for_free_10k

      _any ->
        Sentry.capture_message("Unknown monthly pageview limit for plan",
          extra: %{paddle_plan_id: subscription && subscription.paddle_plan_id}
        )

        :unlimited
    end
  end

  @spec monthly_pageview_usage(Plausible.Auth.User.t()) :: non_neg_integer()
  @doc """
  Returns the amount of pageviews sent by the sites the user owns in last 30 days.
  """
  def monthly_pageview_usage(user) do
    user
    |> Plausible.Billing.usage_breakdown()
    |> Tuple.sum()
  end

  @spec within_limit?(non_neg_integer(), non_neg_integer() | :unlimited) :: boolean()
  @doc """
  Returns whether the limit has been exceeded or not.
  """
  def within_limit?(usage, limit) do
    if limit == :unlimited, do: true, else: usage < limit
  end
end
