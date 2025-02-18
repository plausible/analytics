defmodule Plausible.IngestRepo.Migrations.CreateCustomEventArrayFunction do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION createCustomEventArray
    #{Plausible.MigrationUtils.on_cluster_statement("events_v2")}
    AS (foundIndex, scaleBy) -> (if(foundIndex > 0, [toUInt64(foundIndex + scaleBy)], []));
    """
  end

  def down do
    raise "irreversible"
  end
end
