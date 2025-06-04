defmodule Plausible.Repo.Migrations.RemoveTeamsFromPlanFeatures do
  use Ecto.Migration

  def up do
    execute """
        UPDATE enterprise_plans SET features = array(
          SELECT unnest(features) EXCEPT SELECT unnest('{"teams"}'::varchar[])
        )
    """
  end

  def down do
    raise "irreversible"
  end
end
