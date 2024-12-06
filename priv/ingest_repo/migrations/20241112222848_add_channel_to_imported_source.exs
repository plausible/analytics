defmodule Plausible.IngestRepo.Migrations.AddChannelToImportedSource do
  use Ecto.Migration

  def change do
    alter table(:imported_sources) do
      add :channel, :"LowCardinality(String)"
    end
  end
end
