defmodule Plausible.Repo.Migrations.BackfillTrackerScriptConfiguration do
  use Ecto.Migration

  def change do
    execute(&Plausible.DataMigration.BackfillTrackerScriptConfiguration.run/0, &pass/0)
  end

  defp pass(), do: nil
end
