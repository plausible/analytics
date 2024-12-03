defmodule Plausible.Teams.Adapter.Read.Billing do
  @moduledoc """
  Transition adapter for new schema reads
  """
  use Plausible.Teams.Adapter
  use Plausible

  def quota_usage(user, opts \\ []) do
    switch(user,
      team_fn: &Plausible.Teams.Billing.quota_usage(&1, opts),
      user_fn: &Plausible.Billing.Quota.Usage.usage(&1, opts)
    )
  end

  def allow_next_upgrade_override?(user) do
    switch(user,
      team_fn: &(&1 && &1.allow_next_upgrade_override),
      user_fn: & &1.allow_next_upgrade_override
    )
  end

  def change_plan(user, new_plan_id) do
    switch(user,
      team_fn: &Plausible.Teams.Billing.change_plan(&1, new_plan_id),
      user_fn: &Plausible.Billing.change_plan(&1, new_plan_id)
    )
  end

  def latest_enterprise_plan_with_prices(user, customer_ip) do
    switch(user,
      team_fn: &Plausible.Teams.Billing.latest_enterprise_plan_with_price(&1, customer_ip),
      user_fn: &Plausible.Billing.Plans.latest_enterprise_plan_with_price(&1, customer_ip)
    )
  end

  def has_active_subscription?(user) do
    switch(user,
      team_fn: &Plausible.Teams.Billing.has_active_subscription?/1,
      user_fn: &Plausible.Billing.has_active_subscription?/1
    )
  end

  def active_subscription_for(user) do
    switch(user,
      team_fn: &Plausible.Teams.Billing.active_subscription_for/1,
      user_fn: &Plausible.Billing.active_subscription_for/1
    )
  end

  def check_needs_to_upgrade(user) do
    switch(
      user,
      team_fn: &Teams.Billing.check_needs_to_upgrade/1,
      user_fn: &Plausible.Billing.check_needs_to_upgrade/1
    )
  end

  def ensure_can_add_new_site(user) do
    switch(
      user,
      team_fn: &Teams.Billing.ensure_can_add_new_site/1,
      user_fn: &Plausible.Billing.Quota.ensure_can_add_new_site/1
    )
  end

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
end
