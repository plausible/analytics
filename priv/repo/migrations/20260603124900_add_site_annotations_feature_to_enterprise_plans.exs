defmodule Plausible.Repo.Migrations.AddSiteAnnotationsFeatureToEnterprisePlans do
  use Ecto.Migration

  def up do
    execute """
    UPDATE enterprise_plans
    SET features = array_append(features, 'site_annotations')
    WHERE features @> ARRAY['props', 'stats_api', 'funnels', 'revenue_goals']::varchar[]
      AND NOT (features @> ARRAY['site_annotations']::varchar[])
    """
  end

  def down do
    execute """
    UPDATE enterprise_plans
    SET features = array_remove(features, 'site_annotations')
    WHERE features @> ARRAY['props', 'stats_api', 'funnels', 'revenue_goals', 'site_annotations']::varchar[]
    """
  end
end
