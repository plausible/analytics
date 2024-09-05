defmodule Plausible.IngestRepo.Migrations.AddAcquisitionChannel do
  use Ecto.Migration

  def change do
    alter table(:events_v2) do
      add :channel, :"LowCardinality(String)"
    end

    alter table(:sessions_v2) do
      add :channel, :"LowCardinality(String)"
    end
  end
end
