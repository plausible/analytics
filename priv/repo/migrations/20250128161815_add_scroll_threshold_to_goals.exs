defmodule Plausible.Repo.Migrations.AddScrollThresholdToGoals do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

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

    create(@new_index)
  end

  def down do
    drop(@new_index)

    alter table(:goals) do
      remove :scroll_threshold
    end
  end
end
