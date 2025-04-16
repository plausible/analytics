defmodule Plausible.Repo.Migrations.AddDataRetentionInYearsToPlans do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      alter table(:plans) do
        add :data_retention_in_years, :integer, null: true
      end
    end
  end
end
