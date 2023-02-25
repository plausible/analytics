defmodule Plausible.ClickhouseRepo.Migrations.AddMoreLocationDetails do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:subdivision1_code, :"LowCardinality(String)")
      add(:subdivision2_code, :"LowCardinality(String)")
      add(:city_geoname_id, :UInt32)
    end

    alter table(:sessions) do
      add(:subdivision1_code, :"LowCardinality(String)")
      add(:subdivision2_code, :"LowCardinality(String)")
      add(:city_geoname_id, :UInt32)
    end
  end
end
