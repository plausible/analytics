defmodule Plausible.Repo.Migrations.AddEngagementMetricsEnabledAtToSite do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :engagement_metrics_enabled_at, :naive_datetime, null: true
    end
  end
end
