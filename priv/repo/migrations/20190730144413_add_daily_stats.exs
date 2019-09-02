defmodule Plausible.Repo.Migrations.AddDailyStats do
  use Ecto.Migration

  def change do
    create table(:daily_stats) do
      add :date, :date, null: false
      add :visitors, :integer, null: false
      add :pageviews, :integer, null: false
      add :site_id, references(:sites), null: false

      timestamps()
    end

    create index(:daily_stats, :site_id)
    create index(:daily_stats, :date)
  end
end
