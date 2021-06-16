defmodule Plausible.Repo.Migrations.AddLockedToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :locked, :boolean, null: false, default: false
    end
  end
end
