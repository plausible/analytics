defmodule Plausible.Repo.Migrations.AddNotesToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :notes, :text
    end
  end
end
