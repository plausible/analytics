defmodule Plausible.Repo.Migrations.AddAnalyzerSchemas do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      create table(:analyzer_sites) do
        add :domain, :text, null: false
        add :limit, :integer, null: false
        add :valid_until, :naive_datetime, null: false

        timestamps()
      end

      create unique_index(:analyzer_sites, [:domain])

      create table(:analyzer_logs) do
        add :domain, :text, null: false
        add :request, :jsonb, null: false
        add :headers, :jsonb, null: false
        add :drop_reason, :text, null: true

        timestamps(updated_at: false, type: :naive_datetime_usec)
      end

      create index(:analyzer_logs, [:domain])
    end
  end
end
