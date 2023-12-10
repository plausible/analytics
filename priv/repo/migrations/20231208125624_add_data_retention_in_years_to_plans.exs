defmodule Plausible.Repo.Migrations.AddDataRetentionInYearsToPlans do
  use Ecto.Migration

  def change do
    if !Application.get_env(:plausible, :is_selfhost) do
      alter table(:plans) do
        add :data_retention_in_years, :integer, null: true
      end
    end
  end
end
