defmodule Plausible.Repo.Migrations.AddReviewedAtToTrialProspects do
  use Ecto.Migration

  def change do
    alter table(:trial_prospects) do
      add :reviewed_at, :utc_datetime
    end
  end
end
