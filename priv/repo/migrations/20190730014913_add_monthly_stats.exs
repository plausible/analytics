defmodule Plausible.Repo.Migrations.AddMonthlyStats do
  use Ecto.Migration

  def change do
    create table(:monthly_stats) do
      add :month, :date, null: false
      add :visitors, :integer, null: false
      add :pageviews, :integer, null: false
      add :site_id, references(:sites), null: false

      timestamps()
    end

    create index(:monthly_stats, :site_id)
    create index(:monthly_stats, :month)
  end
end
