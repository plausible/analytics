defmodule Plausible.IngestRepo.Migrations.UpdateAcquisitionChannelUdf do
  use Ecto.Migration

  def change do
    Plausible.DataMigration.AcquisitionChannel.run()
  end
end
