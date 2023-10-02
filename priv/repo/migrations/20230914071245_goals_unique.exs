defmodule Plausible.Repo.Migrations.GoalsUnique do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute """
    DELETE
    FROM
    goals g
    WHERE
    g.id NOT IN (
      SELECT
      min(g2.id)
      FROM
      goals g2
      GROUP BY
      (g2.site_id,
        CASE
        WHEN g2.page_path IS NOT NULL THEN 'Page: ' || g2.page_path
        WHEN g2.event_name IS NOT NULL THEN 'Event: ' || g2.event_name
        END )
    )
    AND g.id NOT IN (
      SELECT fs.goal_id
      FROM funnel_steps fs
    );
    """

    create(
      unique_index(:goals, [:site_id, :event_name],
        where: "event_name IS NOT NULL",
        name: :goals_event_name_unique
      )
    )

    create(
      unique_index(:goals, [:site_id, :page_path],
        where: "page_path IS NOT NULL",
        name: :goals_page_path_unique
      )
    )
  end

  def down do
    drop(unique_index(:goals, [:user_id, :event_name], name: :goals_event_name_unique))
    drop(unique_index(:goals, [:user_id, :page_path], name: :goals_page_path_unique))
  end
end
