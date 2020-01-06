defmodule Plausible.Repo.Migrations.AddEntryPageToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :entry_page, :text
    end

    execute """
    UPDATE sessions SET entry_page = pathname
    FROM events
    WHERE events.user_id = sessions.user_id
    AND events.name = 'pageview'
    AND events.new_visitor
    """

    execute """
    DELETE FROM sessions WHERE entry_page is null
    """

    alter table(:sessions) do
      modify :entry_page, :text, null: false
    end
  end
end
