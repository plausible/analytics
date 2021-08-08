defmodule Plausible.ClickhouseRepo.Migrations.AddMoreLocationDetails do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :country_geoname_id, :UInt32
      add :subdivision1_geoname_id, :UInt32
      add :subdivision2_geoname_id, :UInt32
      add :city_geoname_id, :UInt32
    end

    alter table(:sessions) do
      add :country_geoname_id, :UInt32
      add :subdivision1_geoname_id, :UInt32
      add :subdivision2_geoname_id, :UInt32
      add :city_geoname_id, :UInt32
    end
  end
end
