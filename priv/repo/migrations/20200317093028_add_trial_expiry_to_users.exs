defmodule Plausible.Repo.Migrations.AddTrialExpiryToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :trial_expiry_date, :date
    end

    execute("UPDATE users SET trial_expiry_date=inserted_at::date + interval '30 days'")

    alter table(:users) do
      modify :trial_expiry_date, :date, null: false
    end
  end
end
