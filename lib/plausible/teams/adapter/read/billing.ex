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
end
