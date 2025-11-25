defmodule Plausible.Repo.Migrations.TrackerScriptConfigurationUpdatedAtIndex do
  use Ecto.Migration

  def change do
    create index(:tracker_script_configuration, :updated_at)
  end
end
