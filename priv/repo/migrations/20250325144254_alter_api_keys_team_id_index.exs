defmodule Plausible.Repo.Migrations.AlterApiKeysTeamIdIndex do
  use Ecto.Migration

  def change do
    drop unique_index(:api_keys, [:team_id, :user_id])

    create index(:api_keys, [:team_id])
  end
end
