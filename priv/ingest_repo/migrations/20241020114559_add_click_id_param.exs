defmodule Plausible.IngestRepo.Migrations.AddClickIdParam do
  use Ecto.Migration

  def change do
    alter table(:events_v2) do
      add :click_id_param, :"LowCardinality(String)"
    end

    alter table(:sessions_v2) do
      add :click_id_param, :"LowCardinality(String)"
    end
  end
end
