defmodule Plausible.Repo.Migrations.ShieldCountryRules do
  use Ecto.Migration

  def change do
    create table(:shield_rules_country, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :country_code, :text, null: false
      add :action, :string, default: "deny", null: false
      add :added_by, :string
      timestamps()
    end

    create unique_index(:shield_rules_country, [:site_id, :country_code])
  end
end
