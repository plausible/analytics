defmodule Plausible.DataMigration.AcquisitionChannel do
  @moduledoc """
  Creates functions to calculate acquisition channel in ClickHouse

  SQL files available at: priv/data_migrations/AcquisitionChannel/sql
  """
  use Plausible.DataMigration, dir: "AcquisitionChannel", repo: Plausible.IngestRepo

  @source_categories Application.app_dir(:plausible, "priv/ga4-source-categories.csv")
                     |> File.read!()
                     |> NimbleCSV.RFC4180.parse_string(skip_headers: true)
                     |> Enum.group_by(fn [_source, category] -> category end, fn [
                                                                                   source,
                                                                                   _category
                                                                                 ] ->
                       source
                     end)

  def run(opts \\ []) do
    on_cluster_statement = Plausible.MigrationUtils.on_cluster_statement("sessions_v2")

    unwrap("acquisition_channel_functions")
    |> String.split(";", trim: true)
    |> Enum.each(&create_function(&1, on_cluster_statement, opts))
  end

  defp create_function(sql, on_cluster_statement, opts) do
    sql =
      sql
      |> String.replace(" AS ", " #{on_cluster_statement} AS ")
      |> String.replace("$SOURCE_CATEGORY_SEARCH", "{$0:Array(String)}")
      |> String.replace("$SOURCE_CATEGORY_SHOPPING", "{$1:Array(String)}")
      |> String.replace("$SOURCE_CATEGORY_SOCIAL", "{$2:Array(String)}")
      |> String.replace("$SOURCE_CATEGORY_VIDEO", "{$3:Array(String)}")

    name =
      sql
      |> String.split()
      |> Enum.at(4)

    do_run(name, sql,
      params: [
        @source_categories["SOURCE_CATEGORY_SEARCH"],
        @source_categories["SOURCE_CATEGORY_SHOPPING"],
        @source_categories["SOURCE_CATEGORY_SOCIAL"],
        @source_categories["SOURCE_CATEGORY_VIDEO"]
      ],
      quiet: Keyword.get(opts, :quiet, false)
    )
  end
end
