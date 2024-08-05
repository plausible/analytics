defmodule Plausible.Repo.Migrations.AddGoalDisplayName do
  use Ecto.Migration

  def change do
    alter table(:goals) do
      add :display_name, :text
    end

    create unique_index(:goals, [:site_id, :display_name])

    fill_display_names()

    # alter table(:goals) do
    #   modify :display_name, :text, null: false
    # end
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
