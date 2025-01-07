defmodule Plausible.Repo.Migrations.TeamSetupAt do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :setup_done, :boolean, default: false, null: false
      add :setup_at, :naive_datetime, null: true
    end
  end
end
