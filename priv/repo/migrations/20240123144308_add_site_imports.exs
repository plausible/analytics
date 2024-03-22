defmodule Plausible.Repo.Migrations.AddSiteImports do
  use Ecto.Migration

  def change do
    create table(:site_imports) do
      add :start_date, :date, null: false
      add :end_date, :date, null: false
      add :source, :string, null: false
      add :status, :string, null: false

      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :imported_by_id, references(:users, on_delete: :nilify_all), null: true

      timestamps()
    end

    create index(:site_imports, [:site_id, :start_date])
    create index(:site_imports, [:imported_by_id])
  end
end
