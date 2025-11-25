defmodule Plausible.Repo.Migrations.AuditEntries do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      create table(:audit_entries, primary_key: false) do
        add(:id, :uuid, primary_key: true)
        add :name, :string, null: false
        add :entity, :string, null: false
        add :entity_id, :string, null: false
        add :meta, :map, default: %{}
        add :change, :map, default: %{}
        add :user_id, :integer
        add :team_id, :integer
        add :datetime, :naive_datetime_usec, null: false
        add :actor_type, :string, null: false
      end

      create index(:audit_entries, [:entity])
      create index(:audit_entries, [:entity_id])
      create index(:audit_entries, [:user_id])
      create index(:audit_entries, [:team_id])
      create index(:audit_entries, [:datetime])
    end
  end
end
