defmodule Plausible.Teams.Adapter.Read.Billing do
  @moduledoc """
  Transition adapter for new schema reads
  """
  use Plausible.Teams.Adapter

  def enterprise_configured?(nil), do: false

  def enterprise_configured?(user) do
    switch(user,
      team_fn: &Plausible.Teams.Billing.enterprise_configured?/1,
      user_fn: &Plausible.Auth.enterprise_configured?/1
    )
  end

  def has_active_subscription?(user) do
    switch(user,
      team_fn: &Plausible.Teams.Billing.has_active_subscription?/1,
      user_fn: &Plausible.Billing.has_active_subscription?/1
    )
  end

  def get_subscription(user) do
    case user_or_team(user) do
      %{subscription: subscription} -> subscription
      _ -> nil
    end
  end

  def team_member_limit(user) do
    switch(user,
      team_fn: &Teams.Billing.team_member_limit/1,
      user_fn: &Plausible.Billing.Quota.Limits.team_member_limit/1
    )
  end

  def team_member_usage(user, opts \\ []) do
    switch(user,
      team_fn: &Teams.Billing.team_member_usage(&1, opts),
      user_fn: &Plausible.Billing.Quota.Usage.team_member_usage(&1, opts)
    )
  end

  def monthly_pageview_limit(user) do
    switch(user,
      team_fn: &Teams.Billing.monthly_pageview_limit/1,
      user_fn: &Plausible.Billing.Quota.Limits.monthly_pageview_limit/1
    )
  end

  def monthly_pageview_usage(user, site_ids \\ nil) do
    switch(
      user,
      team_fn: &Teams.Billing.monthly_pageview_usage(&1, site_ids),
      user_fn: &Plausible.Billing.Quota.Usage.monthly_pageview_usage(&1, site_ids)
    )
  end

  def check_needs_to_upgrade(user) do
    switch(
      user,
      team_fn: &Teams.Billing.check_needs_to_upgrade/1,
      user_fn: &Plausible.Billing.check_needs_to_upgrade/1
    )
  end

  def site_limit(user) do
    switch(
      user,
      team_fn: &Teams.Billing.site_limit/1,
      user_fn: &Plausible.Billing.Quota.Limits.site_limit/1
    )
  end

  def ensure_can_add_new_site(user) do
    switch(
      user,
      team_fn: &Teams.Billing.ensure_can_add_new_site/1,
      user_fn: &Plausible.Billing.Quota.ensure_can_add_new_site/1
    )
  end

  def site_usage(user) do
    switch(user,
      team_fn: &Teams.Billing.site_usage/1,
      user_fn: &Plausible.Billing.Quota.Usage.site_usage/1
    )
  end

  use Plausible

  on_ee do
    def check_feature_availability_for_stats_api(user) do
      {unlimited_trial?, subscription?} =
        switch(user,
          team_fn: fn team ->
            team = Plausible.Teams.with_subscription(team)
            unlimited_trial? = is_nil(team) or is_nil(team.trial_expiry_date)

            subscription? =
              not is_nil(team) and Plausible.Billing.Subscriptions.active?(team.subscription)

            {unlimited_trial?, subscription?}
          end,
          user_fn: fn user ->
            user = Plausible.Users.with_subscription(user)
            unlimited_trial? = is_nil(user.trial_expiry_date)
            subscription? = Plausible.Billing.Subscriptions.active?(user.subscription)

            {unlimited_trial?, subscription?}
          end
        )

      pre_business_tier_account? =
        NaiveDateTime.before?(user.inserted_at, Plausible.Billing.Plans.business_tier_launch())

      cond do
        !subscription? && unlimited_trial? && pre_business_tier_account? ->
          :ok

        !subscription? && unlimited_trial? && !pre_business_tier_account? ->
          {:error, :upgrade_required}

        true ->
          check_feature_availability(Plausible.Billing.Feature.StatsAPI, user)
      end
    end
  else
    def check_feature_availability_for_stats_api(_user), do: :ok
  end

  def check_feature_availability(feature, user) do
    switch(user,
      team_fn: fn team_or_nil ->
        cond do
          feature.free?() -> :ok
          feature in Teams.Billing.allowed_features_for(team_or_nil) -> :ok
          true -> {:error, :upgrade_required}
        end
      end,
      user_fn: fn user ->
        cond do
          feature.free?() -> :ok
          feature in Plausible.Billing.Quota.Limits.allowed_features_for(user) -> :ok
          true -> {:error, :upgrade_required}
        end
      end
    )
  end

  def suggest_by_usage(user, usage_during_cycle) do
    subscription = get_subscription(user)
    Plausible.Billing.Plans.suggest_by_usage(subscription, usage_during_cycle)
  end
end
