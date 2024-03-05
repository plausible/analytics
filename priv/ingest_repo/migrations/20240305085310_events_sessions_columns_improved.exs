defmodule Plausible.IngestRepo.Migrations.EventsSessionsColumnsImproved do
  use Ecto.Migration

  @zstd_columns [
    :referrer,
    :referrer_source,
    :utm_medium,
    :utm_source,
    :utm_campaign,
    :utm_content,
    :utm_term
  ]

  def up do
    for column <- @zstd_columns do
      execute "ALTER TABLE events_v2 MODIFY COLUMN #{column} Codec(ZSTD(3))"
    end

    execute "ALTER TABLE events_v2 DROP COLUMN IF EXISTS transferred_from"
  end

  def down do
    raise "Irreversible"
  end
end
