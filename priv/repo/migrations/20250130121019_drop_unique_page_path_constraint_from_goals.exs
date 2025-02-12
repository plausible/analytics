defmodule Plausible.Repo.Migrations.DropUniquePagePathConstraintFromGoals do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Plausible.Repo.Migrations.GoalsUnique
  @old_index unique_index(
               :goals,
               [:site_id, :page_path],
               where: "page_path IS NOT NULL",
               name: :goals_page_path_unique
             )

  def up do
    drop(@old_index)
  end

  def down do
    create(@old_index)
  end
end
