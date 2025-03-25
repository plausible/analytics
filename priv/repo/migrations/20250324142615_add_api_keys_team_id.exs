defmodule Plausible.Repo.Migrations.AddApiKeysTeamId do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :team_id, references(:teams, on_delete: :delete_all), null: true
    end

    create unique_index(:api_keys, [:team_id, :user_id])
  end
end
