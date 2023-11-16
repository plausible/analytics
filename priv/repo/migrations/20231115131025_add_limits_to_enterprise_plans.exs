defmodule Plausible.Repo.Migrations.AddLimitsToEnterprisePlans do
  use Ecto.Migration

  def change do
    alter table(:enterprise_plans) do
      add :team_member_limit, :integer, null: true
      add :features, {:array, :string}
    end

    flush()

    Plausible.Repo.update_all(Plausible.Billing.EnterprisePlan,
      set: [
        team_member_limit: -1,
        features: ["props", "stats_api"]
      ]
    )
  end
end
