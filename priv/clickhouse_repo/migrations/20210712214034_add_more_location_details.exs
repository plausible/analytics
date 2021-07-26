defmodule Plausible.ClickhouseRepo.Migrations.AddMoreLocationDetails do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :continent_geoname_id, :"LowCardinality(String)"
      add :country_geoname_id, :"LowCardinality(String)"
      add :subdivision1_geoname_id, :"LowCardinality(String)"
      add :subdivision2_geoname_id, :"LowCardinality(String)"
      add :city_geoname_id, :"LowCardinality(String)"
    end

    alter table(:sessions) do
      add :continent_geoname_id, :"LowCardinality(String)"
      add :country_geoname_id, :"LowCardinality(String)"
      add :subdivision1_geoname_id, :"LowCardinality(String)"
      add :subdivision2_geoname_id, :"LowCardinality(String)"
      add :city_geoname_id, :"LowCardinality(String)"
    end
  end
end
