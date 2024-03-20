defmodule Plausible.Repo.Migrations.ShieldPageRules do
  use Ecto.Migration

  def change do
    create table(:shield_rules_page, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :page_path, :text, null: false
      add :page_path_pattern, :text, null: false
      add :action, :string, default: "deny", null: false
      add :added_by, :string
      timestamps()
    end

    create unique_index(:shield_rules_page, [:site_id, :page_path_pattern])
  end
end
