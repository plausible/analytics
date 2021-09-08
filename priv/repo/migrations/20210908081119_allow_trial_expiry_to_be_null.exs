defmodule Plausible.Repo.Migrations.AllowTrialExpiryToBeNull do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :trial_expiry_date, :date, null: true
    end
  end
end
