defmodule Plausible.Stats.Filters do
  @moduledoc """
  A module for parsing filters used in stat queries.
  """

  alias Plausible.Stats.Filters.{DashboardFilterParser, StatsAPIFilterParser}

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
    :hostname
  ]
  def visit_props(), do: @visit_props |> Enum.map(&to_string/1)

  @event_props [:name, :page, :goal]

  def event_props(), do: @event_props |> Enum.map(&to_string/1)

  @doc """
  Parses different filter formats.

  Depending on the format and type of the `filters` argument, returns:

    * a decoded map, when `filters` is encoded JSON
    * a parsed filter map, when `filters` is a filter expression string
    * the same map, when `filters` is a map

  Returns an empty map when argument type is unexpected (e.g. `nil`).

  ### Examples:

      iex> Filters.parse("{\\"page\\":\\"/blog/**\\"}")
      %{"event:page" => {:matches, "/blog/**"}}

      iex> Filters.parse("visit:browser!=Chrome")
      %{"visit:browser" => {:is_not, "Chrome"}}

      iex> Filters.parse(nil)
      %{}
  """
  def parse(filters) when is_binary(filters) do
    case Jason.decode(filters) do
      {:ok, filters} when is_map(filters) -> DashboardFilterParser.parse_and_prefix(filters)
      {:ok, _} -> %{}
      {:error, err} -> StatsAPIFilterParser.parse_filter_expression(err.data)
    end
  end

  def parse(filters) when is_map(filters), do: DashboardFilterParser.parse_and_prefix(filters)
  def parse(_), do: %{}

  def without_prefix(property) do
    property
    |> String.split(":")
    |> List.last()
    |> String.to_existing_atom()
  end
end
