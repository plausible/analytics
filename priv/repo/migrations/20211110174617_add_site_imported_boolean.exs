defmodule Plausible.Repo.Migrations.GoogleAuthImportedBoolean do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :has_imported_stats, :boolean
    end
  end
end
