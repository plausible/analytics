defmodule Plausible.Stats.Props do
  alias Plausible.Stats.Query
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base
  @event_props ["event:page", "event:page_match", "event:name", "event:goal"]
  @session_props [
    "visit:source",
    "visit:country",
    "visit:region",
    "visit:city",
    "visit:entry_page",
    "visit:exit_page",
    "visit:referrer",
    "visit:utm_medium",
    "visit:utm_source",
    "visit:utm_campaign",
    "visit:utm_content",
    "visit:utm_term",
    "visit:device",
    "visit:os",
    "visit:os_version",
    "visit:browser",
    "visit:browser_version"
  ]

  def event_props(), do: @event_props

  def valid_prop?(prop) when prop in @event_props, do: true
  def valid_prop?(prop) when prop in @session_props, do: true
  def valid_prop?("event:props:" <> prop) when byte_size(prop) > 0, do: true
  def valid_prop?(_), do: false

  def props(site, query) do
    prop_filter = Query.get_filter_by_prefix(query, "event:props:")
    goal_filter = query.filters["event:goal"]

    case {goal_filter, prop_filter} do
      {{_, {_, goal_name}}, {"event:props:" <> key, _}} when is_binary(goal_name) ->
        %{goal_name => [key]}

      {{_, values}, {"event:props:" <> _, _}} when is_list(values) ->
        nil

      _ ->
        from(e in base_event_query(site, query),
          inner_lateral_join: meta in fragment("meta"),
          select: {e.name, meta.key},
          distinct: true
        )
        |> ClickhouseRepo.all()
        |> group_by_goal_name()
    end
  end

  defp group_by_goal_name(results_list) do
    Enum.reduce(results_list, %{}, fn {goal_name, meta_key}, acc ->
      Map.update(acc, goal_name, [meta_key], fn list -> [meta_key | list] end)
    end)
  end
end
