defmodule Plausible.Repo.Migrations.AddNativeStatsStartDate do
  use Ecto.Migration

  def up do
    alter table(:sites) do
      add :native_stats_start_at, :naive_datetime, null: true
    end

    execute """
    UPDATE sites SET native_stats_start_at = inserted_at
    """

    alter table(:sites) do
      modify :native_stats_start_at, :naive_datetime, null: false, default: fragment("now()")
    end
  end

  def down do
    alter table(:sites) do
      remove :native_stats_start_at
    end
  end
end
