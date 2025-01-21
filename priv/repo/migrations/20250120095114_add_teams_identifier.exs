defmodule Plausible.Repo.Migrations.AddTeamsIdentifier do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :identifier, :binary_id, null: false, default: fragment("gen_random_uuid()")
    end

    create unique_index(:teams, [:identifier])
  end
end
