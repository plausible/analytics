defmodule Plausible.Repo.Migrations.AddTeamsLocked do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :locked, :boolean, null: false, default: false
    end
  end
end
