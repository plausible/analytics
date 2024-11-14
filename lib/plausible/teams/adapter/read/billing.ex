defmodule Plausible.Teams.Adapter.Read.Billing do
  @moduledoc """
  Transition adapter for new schema reads 
  """
  use Plausible.Teams.Adapter

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
end
