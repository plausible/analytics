defmodule Plausible.DataMigration.LocationsSync do
  @moduledoc """
  ClickHouse locations data migration for storing location names in clickhouse.

  Run regularly as plausible/locations data changes.

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
    cluster? = Plausible.MigrationUtils.clustered_table?("sessions_v2")

    {:ok, _} = run_sql("truncate-location-data-table", cluster?: cluster?)
    {:ok, _} = run_sql("create-location-data-table", cluster?: cluster?)

    countries =
      Location.Country.all()
      |> Enum.map(fn country -> %{type: "country", id: country.alpha_2, name: country.name} end)

    subdivisions =
      Location.Subdivision.all()
      |> Enum.map(fn subdivision ->
        %{type: "subdivision", id: subdivision.code, name: subdivision.name}
      end)

    cities =
      Location.City.all()
      |> Enum.map(fn city -> %{type: "city", id: Integer.to_string(city.id), name: city.name} end)

    @repo.insert_all(ClickhouseLocationData, Enum.concat([countries, subdivisions, cities]))

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
