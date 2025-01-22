defmodule Plausible.Repo.Migrations.DropOldOneTeamPerUserConstraint do
  use Ecto.Migration

  def up do
    alter table(:team_memberships) do
      modify :is_autocreated, :boolean, null: false, default: false
    end

    drop unique_index(:team_memberships, [:user_id],
           where: "role != 'guest'",
           name: :one_team_per_user
         )
  end

  def down do
    create unique_index(:team_memberships, [:user_id],
             where: "role != 'guest'",
             name: :one_team_per_user
           )

    alter table(:team_memberships) do
      modify :is_autocreated, :boolean, null: false, default: true
    end
  end
end
