defmodule Plausible.Repo.Migrations.CreateTrialProspects do
  use Ecto.Migration

  def change do
    create table(:trial_prospects) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :estimated_monthly, :integer, null: false
      add :observed_days, :integer, null: false
      add :first_data_day, :date, null: false
      add :kind, :string, null: false

      add :forced_by, {:array, :string}, null: false, default: []
      add :pageview_limit, :integer
      add :over_top_tier, :boolean, null: false, default: false
      add :estimated_mrr, :integer
      add :computed_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:trial_prospects, [:team_id])
    create index(:trial_prospects, [:estimated_mrr])
  end
end
