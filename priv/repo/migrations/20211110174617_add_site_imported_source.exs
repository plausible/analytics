defmodule Plausible.Repo.Migrations.GoogleAuthImportedSource do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :imported_source, :string, null: true, default: nil
    end
  end
end
