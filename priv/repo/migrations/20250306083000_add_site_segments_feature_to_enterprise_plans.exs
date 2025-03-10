defmodule Plausible.Repo.Migrations.AddSiteSegmentsFeatureToEnterprisePlans do
  use Ecto.Migration

  def up do
    execute """
    UPDATE enterprise_plans
    SET features = array_append(features, 'site_segments')
    WHERE features @> ARRAY['props', 'stats_api', 'funnels', 'revenue_goals']::varchar[]
      AND NOT (features @> ARRAY['site_segments']::varchar[])
    """
  end

  def down do
    execute """
    UPDATE enterprise_plans
    SET features = array_remove(features, 'site_segments')
    WHERE features @> ARRAY['props', 'stats_api', 'funnels', 'revenue_goals', 'site_segments']::varchar[]
    """
  end
end
