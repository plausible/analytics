defmodule Plausible.DataMigration.LocationsSync do
  @moduledoc """
  ClickHouse locations data migration for storing location names in ClickHouse.

  Only run when `Location.version()` changes: either as a migration or in cron.

  The migration:
  1. Truncates existing `location_data` table (if exists)
  2. Creates new table (if needed)
  3. Inserts new data from Location module
  4. (Re-)Creates dictionary to read location data from table
  5. Creates ALIAS columns in `events_v2`, `sessions_v2` and `imported_locations` table to make reading location names easy
  6. Updates table comment for `location_data` to indicate last version synced.

  Note that the dictionary is large enough to cache the whole dataset in memory, making lookups fast.

  This migration is intended to be idempotent and rerunnable - if run multiple times, it should always set things to the same
  result as if run once.

  SQL files available at: priv/data_migrations/LocationsSync/sql
  """
  alias Plausible.ClickhouseLocationData

  use Plausible.DataMigration, dir: "LocationsSync", repo: Plausible.IngestRepo

  @columns [
    %{
      table: "events_v2",
      column_name: "country_name",
      type: "country",
      input_column: "country_code"
    },
    %{
      table: "events_v2",
      column_name: "region_name",
      type: "subdivision",
      input_column: "subdivision1_code"
    },
    %{
      table: "events_v2",
      column_name: "city_name",
      type: "city",
      input_column: "city_geoname_id"
    },
    %{
      table: "sessions_v2",
      column_name: "country_name",
      type: "country",
      input_column: "country_code"
    },
    %{
      table: "sessions_v2",
      column_name: "region_name",
      type: "subdivision",
      input_column: "subdivision1_code"
    },
    %{
      table: "sessions_v2",
      column_name: "city_name",
      type: "city",
      input_column: "city_geoname_id"
    },
    %{
      table: "imported_locations",
      column_name: "country_name",
      type: "country",
      input_column: "country"
    },
    %{
      table: "imported_locations",
      column_name: "region_name",
      type: "subdivision",
      input_column: "region"
    },
    %{
      table: "imported_locations",
      column_name: "city_name",
      type: "city",
      input_column: "city"
    }
  ]

  def out_of_date?() do
    case run_sql("get-location-data-table-comment") do
      {:ok, %{rows: [[stored_version]]}} -> stored_version != Location.version()
      _ -> true
    end
  end

  def run() do
    cluster? = Plausible.IngestRepo.clustered_table?("sessions_v2")

    {:ok, _} = run_sql("truncate-location-data-table", cluster?: cluster?)

    {:ok, _} =
      run_sql("create-location-data-table",
        cluster?: cluster?,
        table_settings: Plausible.MigrationUtils.table_settings_expr(:suffix)
      )

    countries =
      Location.Country.all()
      |> Enum.map(fn %Location.Country{alpha_2: alpha_2, name: name} ->
        %{type: "country", id: alpha_2, name: name}
      end)

    subdivisions =
      Location.Subdivision.all()
      |> Enum.map(fn %Location.Subdivision{code: code, name: name} ->
        %{type: "subdivision", id: code, name: name}
      end)

    cities =
      Location.City.all()
      |> Enum.map(fn %Location.City{id: id, name: name} ->
        %{type: "city", id: Integer.to_string(id), name: name}
      end)

    insert_data = Enum.concat([countries, subdivisions, cities])
    @repo.insert_all(ClickhouseLocationData, insert_data)

    {:ok, _} =
      run_sql("update-location-data-dictionary",
        cluster?: cluster?,
        dictionary_connection_params: Plausible.MigrationUtils.dictionary_connection_params()
      )

    for column <- @columns do
      {:ok, _} =
        run_sql("add-alias-column",
          cluster?: cluster?,
          table: column.table,
          column_name: column.column_name,
          type: column.type,
          input_column: column.input_column
        )
    end

    {:ok, _} =
      run_sql("update-location-data-table-comment",
        cluster?: cluster?,
        version: Location.version()
      )
  end
end
