defmodule Plausible.Repo.Migrations.ChangeTeamMembershipsIsAutocreatedDefaultToTrue do
  use Ecto.Migration

  def up do
    alter table(:team_memberships) do
      modify :is_autocreated, :boolean, null: false, default: true
    end

    execute """
    UPDATE team_memberships SET is_autocreated = true WHERE role = 'owner'
    """
  end

  def down do
    alter table(:team_memberships) do
      modify :is_autocreated, :boolean, null: false, default: false
    end
  end
end
