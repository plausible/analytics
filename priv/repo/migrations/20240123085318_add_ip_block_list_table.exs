defmodule Plausible.Repo.Migrations.AddIpBlockListTable do
  use Ecto.Migration

  def change do
    create table(:shield_rules_ip, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add :site_id, references(:sites), null: false
      add :inet, :inet
      add :action, :string, default: "deny", null: false
      add :description, :string
      add :added_by, :string
      timestamps()
    end

    create unique_index(:shield_rules_ip, [:site_id, :inet])
  end
end
