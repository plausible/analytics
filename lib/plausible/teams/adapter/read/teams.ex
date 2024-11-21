defmodule Plausible.Teams.Adapter.Read.Teams do
  @moduledoc """
  Transition adapter for new schema reads
  """
  use Plausible.Teams.Adapter

  def trial_expiry_date(user) do
    switch(user,
      team_fn: &(&1 && &1.trial_expiry_date),
      user_fn: & &1.trial_expiry_date
    )
  end

  def on_trial?(user) do
    switch(user,
      team_fn: &Plausible.Teams.on_trial?/1,
      user_fn: &Plausible.Users.on_trial?/1
    )
  end

  def trial_days_left(user) do
    switch(user,
      team_fn: &Plausible.Teams.trial_days_left/1,
      user_fn: &Plausible.Users.trial_days_left/1
    )
  end
end
