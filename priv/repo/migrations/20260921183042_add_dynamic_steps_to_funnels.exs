defmodule Plausible.Repo.Migrations.AddDynamicStepsToFunnels do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      alter table(:funnels) do
        add :dynamic_steps, :map
      end
    end
  end
end
