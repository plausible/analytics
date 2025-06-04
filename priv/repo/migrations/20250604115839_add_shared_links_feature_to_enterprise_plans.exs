defmodule Plausible.Repo.Migrations.AddSharedLinksFeatureToEnterprisePlans do
  use Ecto.Migration

  def up do
    execute """
    UPDATE enterprise_plans
    SET features = array_append(features, 'shared_links')
    WHERE NOT ('shared_links' = ANY(features));
    """
  end

  def down do
    raise "irreversible"
  end
end
