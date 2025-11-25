defmodule Plausible.Repo.Migrations.AddConsolidatedViewFeatureToEnterprisePlans do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def up do
    if enterprise_edition?() do
      execute """
      UPDATE enterprise_plans
      SET features = array_append(features, 'consolidated_view')
      WHERE features @> ARRAY['revenue_goals', 'props', 'funnels']::varchar[]
        AND NOT (features @> ARRAY['consolidated_view']::varchar[])
      """
    end
  end

  def down do
    if enterprise_edition?() do
      execute """
      UPDATE enterprise_plans
      SET features = array_remove(features, 'consolidated_view')
      WHERE features @> ARRAY['consolidated_view']::varchar[]
      """
    end
  end
end
