defmodule Plausible.Billing.Quota.Limits do
  @moduledoc false

  use Plausible
  alias Plausible.Users
  alias Plausible.Auth.User
  alias Plausible.Billing.{Plan, Plans, Subscription, EnterprisePlan, Feature}
  alias Plausible.Billing.Feature.{Goals, Props, StatsAPI}

  @type over_limits_error() :: {:over_plan_limits, [limit()]}
  @typep limit() :: :site_limit | :pageview_limit | :team_member_limit
  @pageview_allowance_margin 0.1

  on_ee do
    @limit_sites_since ~D[2021-05-05]
    @site_limit_for_trials 10
    @team_member_limit_for_trials 3

    @spec site_limit(User.t()) :: non_neg_integer() | :unlimited
    def site_limit(user) do
      if Date.before?(user.inserted_at, @limit_sites_since) do
        :unlimited
      else
        get_site_limit_from_plan(user)
      end
    end

    defp get_site_limit_from_plan(user) do
      user = Users.with_subscription(user)

      case Plans.get_subscription_plan(user.subscription) do
        %{site_limit: site_limit} -> site_limit
        :free_10k -> 50
        nil -> @site_limit_for_trials
      end
    end

    @spec team_member_limit(User.t()) :: non_neg_integer()
    def team_member_limit(user) do
      user = Users.with_subscription(user)

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

  @monthly_pageview_limit_for_free_10k 10_000
  @monthly_pageview_limit_for_trials :unlimited

  @spec monthly_pageview_limit(User.t() | Subscription.t()) ::
          non_neg_integer() | :unlimited
  def monthly_pageview_limit(%User{} = user) do
    user = Users.with_subscription(user)
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

  def pageview_limit_with_margin(limit, margin \\ nil) do
    margin = if margin, do: margin, else: @pageview_allowance_margin
    ceil(limit * (1 + margin))
  end

  @doc """
  Returns a list of features the user can use. Trial users have the
  ability to use all features during their trial.
  """
  def allowed_features_for(user) do
    user = Users.with_subscription(user)

    case Plans.get_subscription_plan(user.subscription) do
      %EnterprisePlan{features: features} ->
        features

      %Plan{features: features} ->
        features

      :free_10k ->
        [Goals, Props, StatsAPI]

      nil ->
        if Users.on_trial?(user) do
          Feature.list()
        else
          [Goals]
        end
    end
  end
end
