defmodule Plausible.Repo.Migrations.AddOnboardingStatusToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :onboarding_status, :string, null: false, default: "completed"
    end
  end
end
