defmodule Plausible.Repo.Migrations.CreateAuditEntries do
  use Ecto.Migration

  def change do
    create table(:audit_entries) do
      add :name, :string, null: false
      add :entity, :string, null: false
      add :entity_id, :string, null: false
      add :meta, :map, default: %{}
      add :changed_from, :map, default: %{}
      add :changed_to, :map, default: %{}
      add :user_id, :integer
      add :team_id, :integer
      add :datetime, :naive_datetime_usec, null: false
    end

    create index(:audit_entries, [:entity])
    create index(:audit_entries, [:entity_id])
    create index(:audit_entries, [:user_id])
    create index(:audit_entries, [:team_id])
    create index(:audit_entries, [:datetime])
  end
end
