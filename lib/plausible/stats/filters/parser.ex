defmodule Plausible.Stats.Filters.Parser do
  @moduledoc """
  Parses filters in the Stats API v2 format into filter trees.
  """

  alias Plausible.Stats.{Filters, QueryError}

  def parse(filters) when is_list(filters) do
    parse_list(filters, &parse_filter/1)
  end

  def parse(nil), do: {:ok, []}

  def parse_filter_dimension(dimension) do
    if valid_filter_dimension?(dimension) do
      {:ok, dimension}
    else
      {:error, :invalid_filter_dimension}
    end
  end

  defp valid_filter_dimension?("event:props:" <> property_name), do: property_name != ""
  defp valid_filter_dimension?("event:" <> key), do: key in Filters.event_props()
  defp valid_filter_dimension?("visit:" <> key), do: key in Filters.visit_props()
  defp valid_filter_dimension?("segment"), do: true
  defp valid_filter_dimension?(_), do: false

  defp parse_filter(filter) do
    with {:ok, operator} <- parse_operator(filter),
         {:ok, second} <- parse_filter_second(operator, filter),
         {:ok, rest} <- parse_filter_rest(operator, filter) do
      {:ok, [operator, second | rest]}
    end
  end

  defp parse_operator(["is" | _rest]), do: {:ok, :is}
  defp parse_operator(["is_not" | _rest]), do: {:ok, :is_not}
  defp parse_operator(["matches" | _rest]), do: {:ok, :matches}
  defp parse_operator(["matches_not" | _rest]), do: {:ok, :matches_not}
  defp parse_operator(["matches_wildcard" | _rest]), do: {:ok, :matches_wildcard}
  defp parse_operator(["matches_wildcard_not" | _rest]), do: {:ok, :matches_wildcard_not}
  defp parse_operator(["contains" | _rest]), do: {:ok, :contains}
  defp parse_operator(["contains_not" | _rest]), do: {:ok, :contains_not}
  defp parse_operator(["and" | _rest]), do: {:ok, :and}
  defp parse_operator(["or" | _rest]), do: {:ok, :or}
  defp parse_operator(["not" | _rest]), do: {:ok, :not}
  defp parse_operator(["has_done" | _rest]), do: {:ok, :has_done}
  defp parse_operator(["has_not_done" | _rest]), do: {:ok, :has_not_done}

  defp parse_operator(filter),
    do:
      {:error,
       %QueryError{code: :invalid_filters, message: "Unknown operator for filter '#{i(filter)}'."}}

  defp parse_filter_second(operator, [_, filters | _rest]) when operator in [:and, :or],
    do: parse(filters)

  defp parse_filter_second(operator, [_, filter | _rest])
       when operator in [:not, :has_done, :has_not_done],
       do: parse_filter(filter)

  defp parse_filter_second(_operator, [_, filter_dimension | _rest] = filter) do
    case parse_filter_dimension(filter_dimension) do
      {:ok, dimension} ->
        {:ok, dimension}

      {:error, :invalid_filter_dimension} ->
        {:error, %QueryError{code: :invalid_filters, message: "Invalid filter '#{i(filter)}'."}}
    end
  end

  defp parse_filter_second(_operator, filter),
    do: {:error, %QueryError{code: :invalid_filters, message: "Invalid filter '#{i(filter)}'."}}

  defp parse_filter_rest(operator, filter)
       when operator in [
              :is,
              :is_not,
              :matches,
              :matches_not,
              :matches_wildcard,
              :matches_wildcard_not,
              :contains,
              :contains_not
            ] do
    with {:ok, clauses} <- parse_clauses_list(filter),
         {:ok, modifiers} <- parse_filter_modifiers(Enum.at(filter, 3)) do
      {:ok, [clauses | modifiers]}
    end
  end

  defp parse_filter_rest(operator, _filter)
       when operator in [:not, :and, :or, :has_done, :has_not_done],
       do: {:ok, []}

  defp parse_clauses_list([operator, dimension, list | _rest] = filter) when is_list(list) do
    all_strings? = Enum.all?(list, &is_binary/1)
    all_integers? = Enum.all?(list, &is_integer/1)

    case {dimension, all_strings?} do
      {"visit:city", false} when all_integers? ->
        {:ok, list}

      {"visit:country", true} when operator in ["is", "is_not"] ->
        if Enum.all?(list, &(String.length(&1) == 2)) do
          {:ok, list}
        else
          {:error,
           %QueryError{
             code: :invalid_filters,
             message:
               "Invalid visit:country filter, visit:country needs to be a valid 2-letter country code."
           }}
        end

      {"segment", _} when all_integers? ->
        {:ok, list}

      {_, true} when dimension !== "segment" ->
        {:ok, list}

      _ ->
        {:error, %QueryError{code: :invalid_filters, message: "Invalid filter '#{i(filter)}'."}}
    end
  end

  defp parse_clauses_list(filter),
    do: {:error, %QueryError{code: :invalid_filters, message: "Invalid filter '#{i(filter)}'."}}

  defp parse_filter_modifiers(modifiers) when is_map(modifiers) do
    {:ok, [atomize_keys(modifiers)]}
  end

  defp parse_filter_modifiers(nil) do
    {:ok, []}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {String.to_existing_atom(key), value}
    end)
  end

  defp i(value), do: inspect(value, charlists: :as_lists)

  defp parse_list(list, parser_function) do
    Enum.reduce_while(list, {:ok, []}, fn value, {:ok, results} ->
      case parser_function.(value) do
        {:ok, result} -> {:cont, {:ok, results ++ [result]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
