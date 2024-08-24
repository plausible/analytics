defmodule Plausible.IngestRepo.Migrations.AliasApiPropNames do
  @moduledoc """
  Migration adds a ALIAS columns needed to keep DB schema and api
  property naming in sync to reduce overhead in code.
  """

  use Ecto.Migration

  @sessions_prop_names %{
    "source" => "referrer_source",
    "device" => "screen_size",
    "screen" => "screen_size",
    "os" => "operating_system",
    "os_version" => "operating_system_version",
    "country" => "country_code",
    "region" => "subdivision1_code",
    "city" => "city_geoname_id",
    "entry_page_hostname" => "hostname"
  }

  @events_prop_names %{
    "source" => "referrer_source",
    "device" => "screen_size",
    "screen" => "screen_size",
    "os" => "operating_system",
    "os_version" => "operating_system_version",
    "country" => "country_code",
    "region" => "subdivision1_code",
    "city" => "city_geoname_id"
  }

  def up do
    column_types = get_column_types()
    on_cluster = Plausible.MigrationUtils.on_cluster_statement("sessions_v2")

    for {alias_name, column_name} <- @sessions_prop_names do
      execute """
      ALTER TABLE sessions_v2
      #{on_cluster}
      ADD COLUMN #{alias_name} #{Map.fetch!(column_types, column_name)} ALIAS #{column_name}
      """
    end

    for {alias_name, column_name} <- @events_prop_names do
      execute """
      ALTER TABLE events_v2
      #{on_cluster}
      ADD COLUMN #{alias_name} #{Map.fetch!(column_types, column_name)} ALIAS #{column_name}
      """
    end
  end

  def down do
    on_cluster = Plausible.MigrationUtils.on_cluster_statement("sessions_v2")

    for {alias_name, _column_name} <- @sessions_prop_names do
      execute """
      ALTER TABLE sessions_v2
      #{on_cluster}
      DROP COLUMN #{alias_name}
      """
    end

    for {alias_name, _column_name} <- @events_prop_names do
      execute """
      ALTER TABLE events_v2
      #{on_cluster}
      DROP COLUMN #{alias_name}
      """
    end
  end

  def get_column_types() do
    %{rows: rows} =
      Plausible.IngestRepo.query!("""
        SELECT name, type FROM system.columns WHERE table = 'sessions_v2'
      """)

    Map.new(rows, fn [name, type] -> {name, type} end)
  end
end
