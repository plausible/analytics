defmodule Plausible.IngestRepo.Migrations.CreateAcquisitionChannelColumn do
  use Ecto.Migration

  def up do
    Plausible.DataMigration.AcquisitionChannel.run(add_column: true, backfill: false)
  end

  def down do
    raise "irreversible"
  end
end
