defmodule Plausible.Stats.Filters do
  @moduledoc """
  A module for parsing filters used in stat queries.
  """

  alias Plausible.Stats.Filters.QueryParser
  alias Plausible.Stats.Filters.{LegacyDashboardFilterParser, StatsAPIFilterParser}

  @visit_props [
    :source,
    :referrer,
    :utm_medium,
    :utm_source,
    :utm_campaign,
    :utm_content,
    :utm_term,
    :screen,
    :device,
    :browser,
    :browser_version,
    :os,
    :os_version,
    :country,
    :region,
    :city,
    :entry_page,
    :exit_page,
    :entry_page_hostname,
    :exit_page_hostname
  ]
  def visit_props(), do: @visit_props |> Enum.map(&to_string/1)

  @event_table_visit_props @visit_props --
                             [
                               :entry_page,
                               :exit_page,
                               :entry_page_hostname,
                               :exit_page_hostname
                             ]
  def event_table_visit_props(), do: @event_table_visit_props |> Enum.map(&to_string/1)

  @event_props [:name, :page, :goal, :hostname]

  def event_props(), do: @event_props |> Enum.map(&to_string/1)

  @doc """
  Parses different filter formats.

  Depending on the format and type of the `filters` argument, returns:

    * a decoded list, when `filters` is encoded JSON
    * a parsed filter list, when `filters` is a filter expression string
    * the same list, when `filters` is a map

  Returns an empty list when argument type is unexpected (e.g. `nil`).

  ### Examples:

      iex> Filters.parse("{\\"page\\":\\"/blog/**\\"}")
      [[:matches, "event:page", ["/blog/**"]]]

      iex> Filters.parse("visit:browser!=Chrome")
      [[:is_not, "visit:browser", ["Chrome"]]]

      iex> Filters.parse(nil)
      []
  """
  def parse(filters) when is_binary(filters) do
    case Jason.decode(filters) do
      {:ok, filters} when is_map(filters) or is_list(filters) -> parse(filters)
      {:ok, _} -> []
      {:error, err} -> StatsAPIFilterParser.parse_filter_expression(err.data)
    end
  end

  def parse(filters) when is_map(filters),
    do: LegacyDashboardFilterParser.parse_and_prefix(filters)

  def parse(filters) when is_list(filters) do
    {:ok, parsed_filters} = QueryParser.parse_filters(filters)
    parsed_filters
  end

  def parse(_), do: []

  def without_prefix(property) do
    property
    |> String.split(":")
    |> List.last()
    |> String.to_existing_atom()
  end
end
