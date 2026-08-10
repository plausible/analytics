defmodule Plausible.Repo.Migrations.PendingStatsDeletions do
  use Ecto.Migration

  def change do
    create table(:pending_stats_deletions) do
      # site id may not in postgres anymore, so not a reference
      add :site_id, :integer
      add :stats_start_date, :date
      add :stats_end_date, :date
      add :reason, :text

      timestamps()
    end
  end
end
