defmodule Plausible.Repo.Migrations.AddSessionIdToPageviews do
  use Ecto.Migration

  def change do
    alter table(:pageviews) do
      add :session_id, :string
    end
  end
end
