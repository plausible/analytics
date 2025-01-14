defmodule Plausible.Stats.Filters do
  @moduledoc """
  A module for parsing filters used in stat queries.
  """

  alias Plausible.Stats.Query
  alias Plausible.Stats.Filters.QueryParser
  alias Plausible.Stats.Filters.StatsAPIFilterParser

  @visit_props [
    :source,
    :channel,
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
    :country_name,
    :region_name,
    :city_name,
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

    * a parsed filter list, when `filters` is a filter expression string
    * the same list, when `filters` is a map

  Returns an empty list when argument type is unexpected (e.g. `nil`).

  ### Examples:

      iex> Filters.parse("visit:browser!=Chrome")
      [[:is_not, "visit:browser", ["Chrome"]]]

      iex> Filters.parse(nil)
      []
  """
  def parse(filters) when is_binary(filters) do
    case Jason.decode(filters) do
      {:ok, filters} when is_list(filters) -> parse(filters)
      {:ok, _} -> []
      {:error, err} -> StatsAPIFilterParser.parse_filter_expression(err.data)
    end
  end

  def parse(filters) when is_list(filters) do
    {:ok, parsed_filters} = QueryParser.parse_filters(filters)
    parsed_filters
  end

  def parse(_), do: []

  def without_prefix(dimension) do
    dimension
    |> String.split(":")
    |> List.last()
    |> String.to_existing_atom()
  end

  def dimensions_used_in_filters(filters, opts \\ []) do
    min_depth = Keyword.get(opts, :min_depth, 0)
    # :ignore or :only
    behavioral_filter_option = Keyword.get(opts, :behavioral_filters, nil)

    filters
    |> traverse(
      {0, false},
      fn {depth, is_behavioral_filter}, operator ->
        {depth + 1, is_behavioral_filter or operator in [:has_done, :has_done_not]}
      end
    )
    |> Enum.filter(fn {_filter, {depth, _}} -> depth >= min_depth end)
    |> Enum.filter(fn {_filter, {_, is_behavioral_filter}} ->
      case behavioral_filter_option do
        :ignore -> not is_behavioral_filter
        :only -> is_behavioral_filter
        _ -> true
      end
    end)
    |> Enum.map(fn {[_operator, dimension | _rest], _depth} -> dimension end)
  end

  def filtering_on_dimension?(query, dimension) do
    filters =
      case query do
        %Query{filters: filters} -> filters
        %{filters: filters} -> filters
        filters when is_list(filters) -> filters
      end

    dimension in dimensions_used_in_filters(filters)
  end

  def all_leaf_filters(filters) do
    filters
    |> traverse(nil, fn _, _ -> nil end)
    |> Enum.map(fn {filter, _} -> filter end)
  end

  @doc """
  Gets the first top level filter with matching dimension (or nil).

  Only use in cases where it's known that filters are only set on the top level as it
  does not handle AND/OR/NOT!
  """
  def get_toplevel_filter(query, prefix) do
    Enum.find(query.filters, fn [_op, dimension | _rest] ->
      is_binary(dimension) and String.starts_with?(dimension, prefix)
    end)
  end

  def rename_dimensions_used_in_filter(filters, renames) do
    transform_filters(filters, fn
      [operation, dimension | rest] ->
        [[operation, Map.get(renames, dimension, dimension) | rest]]

      _subtree ->
        nil
    end)
  end

  @doc """
  Updates filters via `transformer`.

  Transformer will receive each node (filter, and/or/not subtree) of
  query and must return a list of nodes to replace it with or nil
  to ignore and look deeper.
  """
  def transform_filters(filters, transformer) do
    filters
    |> Enum.flat_map(&transform_tree(&1, transformer))
  end

  defp transform_tree(filter, transformer) do
    case {transformer.(filter), filter} do
      # Transformer did not return that value - transform that subtree
      {nil, [operator, child_filter]} when operator in [:not, :ignore_in_totals_query] ->
        [transformed_child] = transform_tree(child_filter, transformer)
        [[operator, transformed_child]]

      {nil, [operator, filters]} when operator in [:and, :or] ->
        [[operator, transform_filters(filters, transformer)]]

      # Reached a leaf node, return existing value
      {nil, filter} ->
        [[filter]]

      # Transformer returned a value - don't transform that subtree
      {transformed_filters, _filter} ->
        transformed_filters
    end
  end

  @doc """
  Traverses a filter tree while accumulating state.
  """
  def traverse(filters, state, state_transformer) do
    filters
    |> Enum.flat_map(&traverse_tree(&1, state, state_transformer))
  end

  defp traverse_tree(filter, state, state_transformer) do
    case filter do
      [operation, child_filter]
      when operation in [:not, :ignore_in_totals_query, :has_done, :has_done_not] ->
        traverse_tree(child_filter, state_transformer.(state, operation), state_transformer)

      [operation, filters] when operation in [:and, :or] ->
        traverse(filters, state_transformer.(state, operation), state_transformer)

      # Leaf node
      _ ->
        [{filter, state}]
    end
  end
end
