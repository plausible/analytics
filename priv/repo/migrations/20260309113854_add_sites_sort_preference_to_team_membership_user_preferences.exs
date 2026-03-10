defmodule Plausible.Repo.Migrations.AddSitesSortPreferenceToTeamMembershipUserPreferences do
  use Ecto.Migration

  def change do
    alter table(:team_membership_user_preferences) do
      add :sites_sort_by, :string, null: true
      add :sites_sort_direction, :string, null: true
    end
  end
end
