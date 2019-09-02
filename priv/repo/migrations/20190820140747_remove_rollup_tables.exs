defmodule Plausible.Repo.Migrations.RemoveRollupTables do
  use Ecto.Migration

  def change do
    drop table(:daily_stats)
    drop table(:weekly_stats)
    drop table(:monthly_stats)
  end
end
