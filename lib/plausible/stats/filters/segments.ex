defmodule Plausible.Stats.Filters.Segments do
  @moduledoc """
    Module containing the business logic of segments
  """
  alias Plausible.Stats.Filters
  alias Plausible.Stats.Filters.FiltersParser

  @spec has_segment_filters?(list()) :: boolean()
  def has_segment_filters?(filters),
    do: Filters.filtering_on_dimension?(filters, FiltersParser.segment_filter_key())

  @spec expand_segments_to_constituent_filters(list(), list()) ::
          list()
  def expand_segments_to_constituent_filters(filters, segments) do
    case segment_filter_index = find_top_level_segment_filter_index(filters) do
      nil ->
        filters

      _ ->
        {head, [segment_filter | tail]} = Enum.split(filters, segment_filter_index)
        [_operator, _filter_key, segment_id_clauses] = segment_filter

        expanded_filters =
          Enum.concat(
            Enum.map(segment_id_clauses, fn segment_id ->
              with {:ok, segment_data} <- get_segment_data(segments, segment_id),
                   {:ok, %{filters: filters}} <-
                     validate_segment_data(segment_data) do
                filters
              else
                {:error, :segment_not_found} ->
                  raise "Segment not found with id #{inspect(segment_id)}."

                {:error, :segment_invalid} ->
                  raise "Segment invalid with id #{inspect(segment_id)}."
              end
            end)
          )

        head ++ expanded_filters ++ tail
    end
  end

  @spec find_top_level_segment_filter_index(list()) :: non_neg_integer() | nil
  defp find_top_level_segment_filter_index(filters) do
    Enum.find_index(filters, fn filter ->
      case filter do
        [_first, second, _third] -> second == FiltersParser.segment_filter_key()
        _ -> false
      end
    end)
  end

  @spec get_segment_data(list(), integer()) :: {:ok, map()} | {:error, :segment_not_found}
  defp get_segment_data(segments, segment_id) do
    case Enum.find(segments, fn segment -> segment.id == segment_id end) do
      nil -> {:error, :segment_not_found}
      %Plausible.Segment{segment_data: segment_data} -> {:ok, segment_data}
    end
  end

  @spec validate_segment_data(map()) :: {:ok, list()} | {:error, :segment_invalid}
  def validate_segment_data(segment_data) do
    with {:ok, filters} <- FiltersParser.parse_filters(segment_data["filters"]),
         # segments are not permitted within segments
         false <- has_segment_filters?(filters) do
      {:ok, %{filters: filters}}
    else
      _ -> {:error, :segment_invalid}
    end
  end
end
