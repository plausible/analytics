defmodule Plausible.IngestRepo.Migrations.CreateEventsV2SessionColumns do
  use Ecto.Migration

  @columns %{
    session_referrer: {"String", "Codec(ZSTD(3))"},
    session_referrer_source: {"String", "Codec(ZSTD(3))"},
    session_utm_medium: {"String", "Codec(ZSTD(3))"},
    session_utm_source: {"String", "Codec(ZSTD(3))"},
    session_utm_campaign: {"String", "Codec(ZSTD(3))"},
    session_utm_content: {"String", "Codec(ZSTD(3))"},
    session_utm_term: {"String", "Codec(ZSTD(3))"},
    session_country_code: {"LowCardinality(FixedString(2))", ""},
    session_subdivision1_code: {"LowCardinality(String)", ""},
    session_subdivision2_code: {"LowCardinality(String)", ""},
    session_city_geoname_id: {"UInt64", ""},
    session_screen_size: {"LowCardinality(String)", ""},
    session_operating_system: {"LowCardinality(String)", ""},
    session_operating_system_version: {"LowCardinality(String)", ""},
    session_browser: {"LowCardinality(String)", ""},
    session_browser_version: {"LowCardinality(String)", ""}
  }

  def up do
    for {column_name, {type, codec}} <- @columns do
      execute "ALTER TABLE events_v2 ADD COLUMN IF NOT EXISTS #{column_name} #{type} #{codec}"
    end
  end

  def down do
    for {column_name, _} <- @columns do
      execute "ALTER TABLE events_v2 DROP COLUMN IF EXISTS #{column_name}"
    end
  end
end
