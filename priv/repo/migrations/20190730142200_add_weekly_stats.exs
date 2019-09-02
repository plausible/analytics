defmodule Plausible.Repo.Migrations.AddWeeklyStats do
  use Ecto.Migration

  def change do
    create table(:weekly_stats) do
      add :week, :date, null: false
      add :visitors, :integer, null: false
      add :pageviews, :integer, null: false
      add :site_id, references(:sites), null: false

      timestamps()
    end

    create index(:weekly_stats, :site_id)
    create index(:weekly_stats, :week)
  end
end
