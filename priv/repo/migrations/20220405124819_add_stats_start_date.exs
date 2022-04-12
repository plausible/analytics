defmodule Plausible.Repo.Migrations.AddStatsStartDate do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :stats_start_date, :date
    end
  end
end
