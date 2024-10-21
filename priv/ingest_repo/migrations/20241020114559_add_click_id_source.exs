defmodule Plausible.IngestRepo.Migrations.AddClickIdSource do
  use Ecto.Migration

  def change do
    alter table(:events_v2) do
      add :click_id_source, :"LowCardinality(String)"
    end

    alter table(:sessions_v2) do
      add :click_id_source, :"LowCardinality(String)"
    end
  end
end
