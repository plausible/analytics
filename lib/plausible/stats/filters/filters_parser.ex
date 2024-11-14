defmodule Plausible.Stats.Filters.FiltersParser do
  @moduledoc """
    FiltersParser is the module to verify that filters array is in the expected format.
  """

  alias Plausible.Stats.Filters
  alias Plausible.Helpers.ListTraverse

  @segment_filter_key "segment"
  def segment_filter_key(), do: @segment_filter_key

  @filter_entry_operators [
    :is,
    :is_not,
    :matches,
    :matches_not,
    :matches_wildcard,
    :matches_wildcard_not,
    :contains,
    :contains_not
  ]

  @filter_tree_operators [:not, :and, :or]

  def parse_filters(filters) when is_list(filters) do
    ListTraverse.parse_list(filters, &parse_filter/1)
  end

  def parse_filters(_invalid_metrics), do: {:error, "Invalid filters passed."}

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
  defp parse_operator(["not" | _rest]), do: {:ok, :not}
  defp parse_operator(["and" | _rest]), do: {:ok, :and}
  defp parse_operator(["or" | _rest]), do: {:ok, :or}
  defp parse_operator(filter), do: {:error, "Unknown operator for filter '#{i(filter)}'."}

  def parse_filter_second(:not, [_, filter | _rest]), do: parse_filter(filter)

  def parse_filter_second(operator, [_, filters | _rest]) when operator in [:and, :or],
    do: parse_filters(filters)

  def parse_filter_second(_operator, filter), do: parse_filter_key(filter)

  defp parse_filter_key([_operator, filter_key | _rest] = filter) do
    parse_filter_key_string(filter_key, "Invalid filter '#{i(filter)}")
  end

  defp parse_filter_key(filter), do: {:error, "Invalid filter '#{i(filter)}'."}

  defp parse_filter_rest(operator, filter)
       when operator in @filter_entry_operators,
       do: parse_clauses_list(filter)

  defp parse_filter_rest(operator, _filter)
       when operator in @filter_tree_operators,
       do: {:ok, []}

  defp parse_clauses_list([operation, filter_key, list] = filter) when is_list(list) do
    all_strings? = Enum.all?(list, &is_binary/1)
    all_integers? = Enum.all?(list, &is_integer/1)

    case {filter_key, all_strings?} do
      {"visit:city", false} when all_integers? ->
        {:ok, [list]}

      {"visit:country", true} when operation in ["is", "is_not"] ->
        if Enum.all?(list, &(String.length(&1) == 2)) do
          {:ok, [list]}
        else
          {:error,
           "Invalid visit:country filter, visit:country needs to be a valid 2-letter country code."}
        end

      {@segment_filter_key, false} when all_integers? ->
        {:ok, [list]}

      {_, true} ->
        {:ok, [list]}

      _ ->
        {:error, "Invalid filter '#{i(filter)}'."}
    end
  end

  defp parse_clauses_list(filter), do: {:error, "Invalid filter '#{i(filter)}'"}

  def parse_filter_key_string(filter_key, error_message \\ "") do
    case filter_key do
      "event:props:" <> property_name ->
        if String.length(property_name) > 0 do
          {:ok, filter_key}
        else
          {:error, error_message}
        end

      "event:" <> key ->
        if key in Filters.event_props() do
          {:ok, filter_key}
        else
          {:error, error_message}
        end

      "visit:" <> key ->
        if key in Filters.visit_props() do
          {:ok, filter_key}
        else
          {:error, error_message}
        end

      @segment_filter_key ->
        {:ok, filter_key}

      _ ->
        {:error, error_message}
    end
  end

  defp i(value), do: inspect(value, charlists: :as_lists)
end
