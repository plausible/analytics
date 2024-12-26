defmodule Plausible.Stats.Imported.SQL.WhereBuilder do
  @moduledoc """
  A module for building an ecto where clause of a query out of a query for Imported tables.
  """

  import Ecto.Query

  alias Plausible.Stats.Query

  @db_field_mappings %{
    referrer_source: :source,
    screen_size: :device,
    screen: :device,
    os: :operating_system,
    os_version: :operating_system_version,
    country_code: :country,
    subdivision1_code: :region,
    city_geoname_id: :city,
    entry_page_hostname: :hostname,
    pathname: :page,
    url: :link_url
  }

  def build(%Query{filters: []}), do: true

  def build(query) do
    query.filters
    |> Enum.map(&add_filter(query, &1))
    |> Enum.reduce(fn condition, acc -> dynamic([], ^acc and ^condition) end)
  end

  defp add_filter(query, [:ignore_in_totals_query, filter]) do
    add_filter(query, filter)
  end

  defp add_filter(query, [:not, filter]) do
    dynamic([i], not (^add_filter(query, filter)))
  end

  defp add_filter(query, [:and, filters]) do
    filters
    |> Enum.map(&add_filter(query, &1))
    |> Enum.reduce(fn condition, acc -> dynamic([], ^acc and ^condition) end)
  end

  defp add_filter(query, [:or, filters]) do
    filters
    |> Enum.map(&add_filter(query, &1))
    |> Enum.reduce(fn condition, acc -> dynamic([], ^acc or ^condition) end)
  end

  defp add_filter(query, [_operation, dimension, _clauses | _rest] = filter) do
    db_field = Plausible.Stats.Filters.without_prefix(dimension)

    if db_field == :goal do
      Plausible.Goals.Filters.add_filter(query, filter, imported?: true)
    else
      mapped_db_field = Map.get(@db_field_mappings, db_field, db_field)

      Plausible.Stats.SQL.WhereBuilder.build_condition(mapped_db_field, filter)
    end
  end
end
