defmodule Plausible.Stats.CustomProps do
  @moduledoc """
  Module for querying user defined 'custom properties'.
  """

  alias Plausible.Stats.Query
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base

  @doc """
  Returns a breakdown of event names with all existing custom
  properties for each event name.
  """
  def props_for_all_event_names(site, query) do
    from(e in base_event_query(site, query),
      inner_lateral_join: meta in fragment("meta"),
      select: {e.name, meta.key},
      distinct: true
    )
    |> ClickhouseRepo.all()
    |> group_by_goal_name()
  end

  @doc """
  Expects a single goal filter in the query. Returns a list of custom
  props for that goal. Works for both custom event and pageview goals.
  """
  def props_for_goal(site, query) do
    case query.filters["event:goal"] do
      {:is, _} -> fetch_prop_names(site, query)
      {:matches, _} -> fetch_prop_names(site, query)
      _ -> []
    end
  end

  defp fetch_prop_names(site, query) do
    case Query.get_filter_by_prefix(query, "event:props:") do
      {"event:props:" <> key, _} ->
        [key]

      _ ->
        from(e in base_event_query(site, query),
          inner_lateral_join: meta in fragment("meta"),
          select: meta.key,
          distinct: true
        )
        |> ClickhouseRepo.all()
    end
  end

  defp group_by_goal_name(results_list) do
    Enum.reduce(results_list, %{}, fn {goal_name, meta_key}, acc ->
      Map.update(acc, goal_name, [meta_key], fn list -> [meta_key | list] end)
    end)
  end
end
