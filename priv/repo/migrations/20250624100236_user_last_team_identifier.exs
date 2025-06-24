defmodule Plausible.Repo.Migrations.UserLastTeamIdentifier do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_team_identifier, :binary, null: true
    end
  end
end
