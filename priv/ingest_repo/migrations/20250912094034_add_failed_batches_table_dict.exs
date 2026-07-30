defmodule Plausible.IngestRepo.Migrations.AddFailedBatchesTableDict do
  use Ecto.Migration

  def up do
    Plausible.DataMigration.FailedBatches.run()
  end

  def down do
    raise "Irreversible"
  end
end
