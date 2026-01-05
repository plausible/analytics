defmodule Plausible.Repo.Migrations.UpdateGoalsPageviewConfigUniqueConstraint do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop(
      unique_index(:goals, [:site_id, :page_path, :scroll_threshold],
        where: "page_path IS NOT NULL",
        name: :goals_pageview_config_unique
      )
    )

    create(
      unique_index(:goals, [:site_id, :page_path, :scroll_threshold, :custom_props],
        where: "page_path IS NOT NULL",
        name: :goals_pageview_config_unique
      )
    )
  end
end
