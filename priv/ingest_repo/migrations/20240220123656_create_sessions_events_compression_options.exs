defmodule Plausible.IngestRepo.Migrations.CreateSessionsEventsCompressionOptions do
  @moduledoc """
  Improves compression options for events_v2 and sessions_v2 tables.

  It's suggested to run OPTIMIZE both tables after this to get full compression wins afterwards
  """

  use Ecto.Migration

  @sessions_codecs %{
    timestamp: "Codec(Delta(4), LZ4)",
    start: "Codec(Delta(4), LZ4)",
    entry_page: "Codec(ZSTD(3))",
    exit_page: "Codec(ZSTD(3))",
    hostname: "Codec(ZSTD(3))",
    referrer: "Codec(ZSTD(3))",
    referrer_source: "Codec(ZSTD(3))",
    utm_medium: "Codec(ZSTD(3))",
    utm_source: "Codec(ZSTD(3))",
    utm_campaign: "Codec(ZSTD(3))",
    utm_content: "Codec(ZSTD(3))",
    utm_term: "Codec(ZSTD(3))",
    "entry_meta.key": "Codec(ZSTD(3))",
    "entry_meta.value": "Codec(ZSTD(3))"
  }

  @events_codecs %{
    hostname: "Codec(ZSTD(3))",
    "meta.key": "Codec(ZSTD(3))",
    "meta.value": "Codec(ZSTD(3))"
  }

  def up do
    for {column, codec} <- @sessions_codecs do
      execute "ALTER TABLE sessions_v2 MODIFY COLUMN #{column} #{codec}"
    end

    for {column, codec} <- @events_codecs do
      execute "ALTER TABLE events_v2 MODIFY COLUMN #{column} #{codec}"
    end
  end

  # No need to explicitly revert
  def down, do: nil
end
