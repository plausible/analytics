defmodule Plausible.Repo.Migrations.GoalsUnique do
  use Ecto.Migration

  def up do
    execute """
    DELETE
    FROM
    goals
    WHERE
    id NOT IN (
      SELECT
      min(id)
      FROM
      goals
      GROUP BY
      (site_id,
        CASE
        WHEN page_path IS NOT NULL THEN page_path
        WHEN event_name IS NOT NULL THEN event_name
        END )
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
