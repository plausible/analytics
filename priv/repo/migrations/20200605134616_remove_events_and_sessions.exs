defmodule Plausible.Repo.Migrations.RemoveEventsAndSessions do
  use Ecto.Migration

  def change do
    drop table(:events)
    drop table(:sessions)
  end
end
