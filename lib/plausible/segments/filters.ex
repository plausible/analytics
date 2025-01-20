defmodule Plausible.Segments.Filters do
  @moduledoc """
  This module contains functions that enable resolving segments in filters.
  """
  alias Plausible.Segments
  alias Plausible.Stats.Filters

  @max_segment_filters_count 10

  @doc """
  Finds unique segment IDs used in query filters.

  ## Examples
    iex> get_segment_ids([[:not, [:is, "segment", [10, 20]]], [:contains, "visit:entry_page", ["blog"]]])
    {:ok, [10, 20]}

    iex> get_segment_ids([[:and, [[:is, "segment", Enum.to_list(1..6)], [:is, "segment", Enum.to_list(1..6)]]]])
    {:error, "Invalid filters. You can only use up to 10 segment filters in a query."}
  """
  def get_segment_ids(filters) do
    ids =
      filters
      |> Filters.traverse()
      |> Enum.flat_map(fn
        {[_operation, "segment", clauses], _depth} -> clauses
        _ -> []
      end)

    if length(ids) > @max_segment_filters_count do
      {:error,
       "Invalid filters. You can only use up to #{@max_segment_filters_count} segment filters in a query."}
    else
      {:ok, Enum.uniq(ids)}
    end
  end

  def preload_needed_segments(%Plausible.Site{} = site, filters) do
    with {:ok, segment_ids} <- get_segment_ids(filters),
         {:ok, segments} <-
           Segments.get_many(
             site,
             segment_ids,
             fields: [:id, :segment_data]
           ),
         {:ok, segments_by_id} <-
           {:ok,
            Enum.into(
              segments,
              %{},
              fn %Segments.Segment{id: id, segment_data: segment_data} ->
                case Filters.QueryParser.parse_filters(segment_data["filters"]) do
                  {:ok, filters} -> {id, filters}
                  _ -> {id, nil}
                end
              end
            )},
         :ok <-
           if(Enum.any?(segment_ids, fn id -> is_nil(Map.get(segments_by_id, id)) end),
             do: {:error, "Invalid filters. Some segments don't exist or aren't accessible."},
             else: :ok
           ) do
      {:ok, segments_by_id}
    end
  end

  defp replace_segment_with_filter_tree([_, "segment", clauses], preloaded_segments) do
    if length(clauses) === 1 do
      [[:and, Map.get(preloaded_segments, Enum.at(clauses, 0))]]
    else
      [[:or, Enum.map(clauses, fn id -> [:and, Map.get(preloaded_segments, id)] end)]]
    end
  end

  defp replace_segment_with_filter_tree(_filter, _preloaded_segments) do
    nil
  end

  @doc """
  ## Examples

    iex> resolve_segments([[:is, "visit:entry_page", ["/home"]]], %{})
    {:ok, [[:is, "visit:entry_page", ["/home"]]]}

    iex> resolve_segments([[:is, "visit:entry_page", ["/home"]], [:is, "segment", [1]]], %{1 => [[:contains, "visit:entry_page", ["blog"]], [:is, "visit:country", ["PL"]]]})
    {:ok, [
      [:is, "visit:entry_page", ["/home"]],
      [:and, [[:contains, "visit:entry_page", ["blog"]], [:is, "visit:country", ["PL"]]]]
    ]}

    iex> resolve_segments([[:is, "segment", [1, 2]]], %{1 => [[:contains, "event:goal", ["Singup"]], [:is, "visit:country", ["PL"]]], 2 => [[:contains, "event:goal", ["Sauna"]], [:is, "visit:country", ["EE"]]]})
    {:ok, [
      [:or, [
        [:and, [[:contains, "event:goal", ["Singup"]], [:is, "visit:country", ["PL"]]]],
        [:and, [[:contains, "event:goal", ["Sauna"]], [:is, "visit:country", ["EE"]]]]]
      ]
    ]}
  """
  def resolve_segments(original_filters, preloaded_segments) do
    if map_size(preloaded_segments) > 0 do
      {:ok,
       Filters.transform_filters(original_filters, fn f ->
         replace_segment_with_filter_tree(f, preloaded_segments)
       end)}
    else
      {:ok, original_filters}
    end
  end
end
