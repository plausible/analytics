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

  def run(batch_size \\ 100) do
    total_configs = count_total_configurations()
    IO.puts("Found #{total_configs} total tracker configurations to process")

    process_batch(nil, total_configs, batch_size, 0)
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

  defp process_batch(last_id, total_configs, batch_size, processed_count) do
    configs = get_configurations_batch(last_id, batch_size)

    if length(configs) > 0 do
      batch_num = div(processed_count, batch_size) + 1
      start_pos = processed_count + 1
      end_pos = processed_count + length(configs)

      IO.puts("Processing batch #{batch_num} (#{start_pos}-#{end_pos} of #{total_configs})")

      process_configurations_batch(configs, batch_num)

      process_batch(
        List.last(configs).id,
        total_configs,
        batch_size,
        processed_count + length(configs)
      )
    else
      IO.puts("Migration completed!")
    end
  end

  defp get_configurations_batch(last_id, batch_size) do
    query =
      from(config in TrackerScriptConfiguration,
        where: not like(config.id, "pa-%"),
        order_by: [asc: config.id],
        limit: ^batch_size,
        select: %{
          id: config.id
        }
      )

    query =
      if last_id do
        from(config in query, where: config.id > ^last_id)
      else
        query
      end

    Repo.all(query)
  end

  defp process_configurations_batch(configs, batch_num) do
    config_ids = Enum.map(configs, & &1.id)

    case Repo.query(
           "UPDATE tracker_script_configuration SET id = 'pa-' || id WHERE id = ANY($1)",
           [config_ids]
         ) do
      {:ok, %{num_rows: updated_count}} ->
        if updated_count != length(configs) do
          IO.puts(
            "Warning: Batch #{batch_num} - Expected to update #{length(configs)} configurations, but updated #{updated_count}"
          )
        end

      {:error, error} ->
        IO.puts("Error updating batch #{batch_num}: #{inspect(error)}")
        # Continue with next batch instead of crashing
    end
  end
end
