defmodule Plausible.Repo.Migrations.GoogleAuthImportedSource do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :imported_data, :map
    end
  end
end
