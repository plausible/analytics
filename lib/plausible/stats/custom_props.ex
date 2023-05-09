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
      group_by: e.name,
      select: {e.name, fragment("groupArray(?)", meta.key)},
      distinct: true
    )
    |> ClickhouseRepo.all()
    |> Enum.into(%{})
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
        all_props_allowed = is_nil(site.allowed_event_props)
        allowed_props = if all_props_allowed, do: [], else: site.allowed_event_props

        from(e in base_event_query(site, query),
          inner_lateral_join: meta in fragment("meta"),
          select: meta.key,
          where: ^all_props_allowed or meta.key in ^allowed_props,
          distinct: true
        )
        |> ClickhouseRepo.all()
    end
  end
end
