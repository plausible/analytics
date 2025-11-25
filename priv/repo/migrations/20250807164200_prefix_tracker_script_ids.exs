defmodule Plausible.Repo.Migrations.PrefixTrackerScriptConfigurationId do
  use Ecto.Migration

  def up do
    Plausible.DataMigration.PrefixTrackerScriptConfigurationId.run()
  end

  def down do
    # The IDs have been changed and cannot be easily reverted
    raise "Irreversible"
  end
end
