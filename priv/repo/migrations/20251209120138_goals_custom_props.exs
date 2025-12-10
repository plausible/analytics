defmodule Plausible.Repo.Migrations.GoalsCustomProps do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # adds custom_props to goals, but also updates unique constraints to guard for either display name 
  # or broadly speaking "goal configuration"

  def change do
    drop(unique_index(:goals, [:user_id, :event_name], name: :goals_event_name_unique))

    drop(
      unique_index(:goals, [:site_id, :page_path, :scroll_threshold],
        name: :goals_page_path_and_scroll_threshold_unique
      )
    )

    drop(unique_index(:goals, [:site_id, :display_name], name: :goals_site_id_display_name_index))

    alter table(:goals) do
      add(:custom_props, :map)
    end

    create(
      unique_index(:goals, [:site_id, :event_name, :custom_props],
        where: "event_name IS NOT NULL",
        name: :goals_event_config_unique
      )
    )

    create(
      unique_index(:goals, [:site_id, :page_path, :scroll_threshold],
        where: "page_path IS NOT NULL",
        name: :goals_pageview_config_unique
      )
    )

    create(unique_index(:goals, [:site_id, :display_name], name: :goals_display_name_unique))
  end
end
