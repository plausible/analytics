defmodule Plausible.Repo.Migrations.AddSessionStart do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :start, :naive_datetime
    end

    execute "UPDATE sessions set start = timestamp"

    alter table(:sessions) do
      modify :start, :naive_datetime, null: false
    end
  end
end
