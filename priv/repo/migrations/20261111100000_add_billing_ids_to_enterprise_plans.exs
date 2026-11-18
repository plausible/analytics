defmodule Plausible.Repo.Migrations.AddBillingIdsToEnterprisePlans do
  use Ecto.Migration

  def change do
    alter table(:enterprise_plans) do
      add :billing_product_id, :string
      add :billing_price_id, :string
    end

    create unique_index(:enterprise_plans, [:team_id, :billing_product_id])
  end
end
