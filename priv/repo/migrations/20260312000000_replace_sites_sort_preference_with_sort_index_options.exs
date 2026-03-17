defmodule Plausible.Repo.Migrations.ReplaceSitesSortPreferenceWithSortIndexOptions do
  use Ecto.Migration

  def up do
    alter table(:team_membership_user_preferences) do
      remove :sites_sort_by
      remove :sites_sort_direction
      add :sort_index_options, :map, null: false, default: "{}"
    end
  end

  def down do
    alter table(:team_membership_user_preferences) do
      remove :sort_index_options, :map
      add :sites_sort_by, :string, null: true
      add :sites_sort_direction, :string, null: true
    end
  end
end
