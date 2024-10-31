defmodule Plausible.Repo.Migrations.AddScrollThresholdToGoals do
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

  @new_index unique_index(
               :goals,
               [:site_id, :page_path, :scroll_threshold],
               where: "page_path IS NOT NULL",
               name: :goals_page_path_and_scroll_threshold_unique
             )

  def up do
    alter table(:goals) do
      add :scroll_threshold, :smallint, null: false, default: -1
    end

    drop(@old_index)
    create(@new_index)
  end

  def down do
    drop(@new_index)
    create(@old_index)

    alter table(:goals) do
      remove :scroll_threshold
    end
  end
end
