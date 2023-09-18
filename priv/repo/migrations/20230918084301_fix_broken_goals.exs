defmodule Plausible.Repo.Migrations.FixBrokenGoals do
  use Ecto.Migration

  def up do
    execute """
    UPDATE goals SET page_path = NULL WHERE page_path IS NOT NULL AND event_name IS NOT NULL
    """

    execute("""
     ALTER TABLE goals
     ADD CONSTRAINT check_event_name_or_page_path
     CHECK (
       (event_name IS NOT NULL AND page_path IS NULL) OR
       (event_name IS NULL AND page_path IS NOT NULL)
     );
    """)
  end

  def down do
    execute """
    ALTER TABLE goals
    DROP CONSTRAINT check_event_name_or_page_path;
    """
  end
end
