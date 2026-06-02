defmodule Plausible.IngestRepo.Migrations.UpdateAcquisitionChannel do
  use Ecto.Migration

  def up do
    # Rebuilds the ClickHouse dictionaries and SQL functions with the updated
    # source categories (AI Assistants channel, Bluesky, Mastodon, X (Twitter),
    # Google Gemini), then backfills all historical rows.
    #
    # This must run after 20260601000001_remap_sources_v3.exs so that
    # referrer_source values have already been remapped to their canonical names.
    Plausible.DataMigration.AcquisitionChannel.run(update_column: true, backfill: true)
  end

  def down do
    raise "irreversible"
  end
end
