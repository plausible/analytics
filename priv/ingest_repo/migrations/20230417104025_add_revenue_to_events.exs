defmodule Plausible.IngestRepo.Migrations.AddRevenueToEvents do
  use Ecto.Migration

  def change do
    alter table(:events_v2) do
      add :revenue_reporting_amount, :"Nullable(Decimal64(3))"
      add :revenue_reporting_currency, :"FixedString(3)"

      add :revenue_source_amount, :"Nullable(Decimal64(3))"
      add :revenue_source_currency, :"FixedString(3)"
    end
  end
end
