defmodule Plausible.Repo.Migrations.AddAutocreatedToTeamMemberships do
  use Ecto.Migration

  def change do
    alter table(:team_memberships) do
      add :is_autocreated, :boolean, null: false, default: false
    end

    create unique_index(:team_memberships, [:user_id],
             where: "role = 'owner' and is_autocreated = true",
             name: :one_autocreated_owner_per_user
           )

    execute """
            UPDATE team_memberships SET is_autocreated = true WHERE role = 'owner'
            """,
            """
            SELECT 1
            """
  end
end
