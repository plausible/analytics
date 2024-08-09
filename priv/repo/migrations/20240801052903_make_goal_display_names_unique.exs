defmodule Plausible.Repo.Migrations.MakeGoalDisplayNamesUnique do
  use Ecto.Migration

  def up do
    fill_display_names()

    alter table(:goals) do
      modify :display_name, :text, null: false
    end

    create unique_index(:goals, [:site_id, :display_name])
  end

  def down do
    drop unique_index(:goals, [:site_id, :display_name])

    alter table(:goals) do
      modify :display_name, :text, null: true
    end

    execute """
    UPDATE goals
    SET display_name = NULL
    """
  end

  def fill_display_names do
    execute """
    UPDATE goals
    SET display_name = 
      CASE
    WHEN page_path IS NOT NULL THEN 'Visit ' || page_path
    WHEN event_name IS NOT NULL THEN event_name
    END
    """
  end
end
