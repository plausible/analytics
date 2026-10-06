defmodule Plausible.Repo.Migrations.AddTeamIdPaddlePlanIdUniqueIndexToEnterprisePlans do
  use Ecto.Migration

  def change do
    create unique_index(:enterprise_plans, [:team_id, :paddle_plan_id])

    # The previous index is redundant now
    drop index(:enterprise_plans, [:team_id])
  end
end
