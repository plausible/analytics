defmodule Plausible.Repo.Migrations.GoogleAuthImportedBoolean do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :has_imported_stats, :string, null: true, default: nil
    end
  end
end
