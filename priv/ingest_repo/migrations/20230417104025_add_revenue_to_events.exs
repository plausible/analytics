defmodule Plausible.IngestRepo.Migrations.AddRevenueToEvents do
  use Ecto.Migration

  def change do
    alter table(:events_v2) do
      add :revenue_reporting_amount, :"Decimal64(4)"
      add :revenue_reporting_currency, :"LowCardinality(FixedString(3))"

      add :revenue_source_amount, :"Decimal64(4)"
      add :revenue_source_currency, :"LowCardinality(FixedString(3))"
    end
  end
end
