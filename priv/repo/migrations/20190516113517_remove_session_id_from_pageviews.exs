defmodule Plausible.Repo.Migrations.RemoveSessionIdFromPageviews do
  use Ecto.Migration

  def change do
    alter table(:pageviews) do
      remove :session_id
    end
  end
end
