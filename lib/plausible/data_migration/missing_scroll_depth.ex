defmodule Plausible.DataMigration.MissingScrollDepth do
  @moduledoc """
  Set scroll_depth to 255 (max UInt8) for all pageleave events where it's 0.
  """

  def run() do
    Plausible.IngestRepo.query!(
      """
      ALTER TABLE events_v2
      #{Plausible.MigrationUtils.on_cluster_statement("events_v2")}
      UPDATE scroll_depth = 255
      WHERE name = 'pageleave' AND scroll_depth = 0
      """,
      [],
      timeout: 60_000
    )
  end
end
