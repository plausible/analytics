defmodule Plausible.Repo.Migrations.TeamMembershipUserPreferences do
  use Ecto.Migration

  def change do
    create table(:team_membership_user_preferences) do
      add :consolidated_view_cta_dismissed, :boolean, default: false
      add :team_membership_id, references(:team_memberships, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:team_membership_user_preferences, [:team_membership_id])
  end
end
