defmodule Plausible.DataMigration.PrefixTrackerScriptConfigurationId do
  @moduledoc """
  Migration to update tracker script configuration IDs to use the new prefixed format.

  This migration:
  1. Processes tracker configurations in batches to avoid memory issues
  2. Uses batch updates for better performance
  3. Handles the case where tracker configurations might not exist for all sites
  4. Provides progress logging
  """

  import Ecto.Query
  alias Plausible.Repo
  alias Plausible.Site.TrackerScriptConfiguration

  @batch_size 100

  def run do
    total_configs = count_total_configurations()
    IO.puts("Found #{total_configs} total tracker configurations to process")

    process_batch(0, total_configs)
  end

  defp count_total_configurations do
    Repo.aggregate(
      from(config in TrackerScriptConfiguration,
        where: not like(config.id, "pa-%")
      ),
      :count,
      :id
    )
  end

  defp process_batch(offset, total_configs) do
    configs = get_configurations_batch(offset)

    if length(configs) > 0 do
      IO.puts(
        "Processing batch #{div(offset, @batch_size) + 1} (#{offset + 1}-#{offset + length(configs)} of #{total_configs})"
      )

      process_configurations_batch(configs)
      process_batch(offset + @batch_size, total_configs)
    else
      IO.puts("Migration completed!")
    end
  end

  defp get_configurations_batch(offset) do
    Repo.all(
      from(config in TrackerScriptConfiguration,
        where: not like(config.id, "pa-%"),
        order_by: [asc: config.id],
        limit: ^@batch_size,
        offset: ^offset,
        select: %{
          id: config.id
        }
      )
    )
  end

  defp process_configurations_batch(configs) do
    config_ids = Enum.map(configs, & &1.id)

    case Repo.query(
           "UPDATE tracker_script_configuration SET id = 'pa-' || id WHERE id = ANY($1)",
           [config_ids]
         ) do
      {:ok, %{num_rows: updated_count}} ->
        if updated_count != length(configs) do
          IO.puts(
            "  Warning: Expected to update #{length(configs)} configurations, but updated #{updated_count}"
          )
        end

      {:error, error} ->
        IO.puts("  Error updating batch: #{inspect(error)}")
        # Continue with next batch instead of crashing
    end
  end
end
