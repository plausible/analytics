defmodule Plausible.Auth.UserAdmin do
  use Plausible.Repo

  def form_fields(_) do
    [
      name: nil,
      email: nil,
      trial_expiry_date: nil
    ]
  end

  def index(_) do
    [
      name: nil,
      email: nil,
      email_verified: nil,
      trial_expiry_date: nil,
      inserted_at: nil,
      last_seen: nil
    ]
  end
end
