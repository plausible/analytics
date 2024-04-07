defmodule Plausible.Repo.Migrations.ShieldHostnameRules do
  use Ecto.Migration

  def change do
    create table(:shield_rules_hostname, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :hostname, :text, null: false
      add :hostname_pattern, :text, null: false
      add :action, :string, default: "allow", null: false
      add :added_by, :string
      timestamps()
    end

    create unique_index(:shield_rules_hostname, [:site_id, :hostname_pattern])
  end
end
