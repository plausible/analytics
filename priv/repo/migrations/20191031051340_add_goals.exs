defmodule Plausible.Repo.Migrations.AddGoals do
  use Ecto.Migration

  def change do
    create table(:goals) do
      add :domain, :text, null: false
      add :name, :text, null: false
      add :event_name, :text
      add :page_path, :text

      timestamps()
    end

    create unique_index(:goals, [:domain, :name])
  end
end
