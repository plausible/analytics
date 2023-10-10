defmodule Plausible.Repo.Migrations.FixBrokenGoals do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("""
    UPDATE goals SET page_path = NULL WHERE page_path IS NOT NULL AND event_name IS NOT NULL
    """)

    execute("""
    ALTER TABLE goals
    DROP CONSTRAINT IF EXISTS check_event_name_or_page_path;
    """)

    execute("""
     ALTER TABLE goals
     ADD CONSTRAINT check_event_name_or_page_path
     CHECK (
       (event_name IS NOT NULL AND page_path IS NULL) OR
       (event_name IS NULL AND page_path IS NOT NULL)
     )
     NOT VALID;
    """)
  end

  def down do
    execute("""
    ALTER TABLE goals
    DROP CONSTRAINT IF EXISTS check_event_name_or_page_path;
    """)
  end
end
