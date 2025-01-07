defmodule :"Elixir.Plausible.Repo.Migrations.Team-setup-at" do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :setup_done, :boolean, default: false, null: false
      add :setup_at, :naive_datetime, null: true
    end

    create index(:teams, :setup_done)
  end
end
