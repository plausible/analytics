defmodule Plausible.Repo.Migrations.InitFunnels do
  use Ecto.Migration

  def change do
    create table(:funnels) do
      add :name, :string, null: false
      add :site_id, references(:sites), null: false
      timestamps()
    end

    create table(:funnel_steps) do
      add :goal_id, references(:goals), null: false
      add :funnel_id, references(:funnels, on_delete: :delete_all), null: false
      add :step_order, :integer, null: false
      timestamps()
    end

    create unique_index(:funnel_steps, [:goal_id, :funnel_id])
  end
end
