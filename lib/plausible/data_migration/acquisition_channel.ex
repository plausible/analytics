defmodule Plausible.DataMigration.AcquisitionChannel do
  @moduledoc """
  Creates functions to calculate acquisition channel in ClickHouse

  SQL files available at: priv/data_migrations/AcquisitionChannel/sql
  """
  use Plausible.DataMigration, dir: "AcquisitionChannel", repo: Plausible.IngestRepo

  def run(opts \\ []) do
    source_categories =
      Plausible.Ingestion.Acquisition.source_categories()
      |> invert_map()

    on_cluster_statement = Plausible.MigrationUtils.on_cluster_statement("sessions_v2")

    unwrap("acquisition_channel_functions")
    |> String.trim()
    |> String.split(";", trim: true)
    |> Enum.each(&create_function(&1, on_cluster_statement, source_categories, opts))
  end

  defp create_function(sql, on_cluster_statement, source_categories, opts) do
    sql =
      sql
      |> String.replace(" AS ", " #{on_cluster_statement} AS ")
      |> String.replace("$SOURCE_CATEGORY_SEARCH", "{$0:Array(String)}")
      |> String.replace("$SOURCE_CATEGORY_SHOPPING", "{$1:Array(String)}")
      |> String.replace("$SOURCE_CATEGORY_SOCIAL", "{$2:Array(String)}")
      |> String.replace("$SOURCE_CATEGORY_VIDEO", "{$3:Array(String)}")
      |> String.replace("$SOURCE_CATEGORY_EMAIL", "{$4:Array(String)}")
      |> String.replace("$PAID_SOURCES", "{$5:Array(String)}")

    name =
      sql
      |> String.split()
      |> Enum.at(4)

    {:ok, _} =
      do_run(name, sql,
        params: [
          source_categories["SOURCE_CATEGORY_SEARCH"],
          source_categories["SOURCE_CATEGORY_SHOPPING"],
          source_categories["SOURCE_CATEGORY_SOCIAL"],
          source_categories["SOURCE_CATEGORY_VIDEO"],
          source_categories["SOURCE_CATEGORY_EMAIL"],
          Plausible.Ingestion.Source.paid_sources()
        ],
        quiet: Keyword.get(opts, :quiet, false)
      )
  end

  defp invert_map(source_categories) do
    source_categories
    |> Enum.group_by(
      fn {_source, category} -> category end,
      fn {source, _category} -> source end
    )
  end
end
