defmodule Plausible.Teams.Adapter.Read.Billing do
  @moduledoc """
  Transition adapter for new schema reads
  """
  use Plausible.Teams.Adapter
  use Plausible

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
