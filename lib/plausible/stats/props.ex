defmodule Plausible.Stats.Props do
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
    prop_filter =
      Enum.find(query.filters, fn {key, _} -> String.starts_with?(key, "event:props:") end)

    case prop_filter do
      {"event:props:" <> key, {_, "(none)"}} ->
        {_, _, goal_name} = query.filters["event:goal"]
        %{goal_name => [key]}

      {"event:props:" <> _key, _} ->
        ClickhouseRepo.all(
          from [e, meta: meta] in base_event_query(site, query),
            select: {e.name, meta.key},
            distinct: true
        )
        |> Enum.reduce(%{}, fn {goal_name, meta_key}, acc ->
          Map.update(acc, goal_name, [meta_key], fn list -> [meta_key | list] end)
        end)

      nil ->
        ClickhouseRepo.all(
          from e in base_event_query(site, query),
            inner_lateral_join: meta in fragment("meta"),
            select: {e.name, meta.key},
            distinct: true
        )
        |> Enum.reduce(%{}, fn {goal_name, meta_key}, acc ->
          Map.update(acc, goal_name, [meta_key], fn list -> [meta_key | list] end)
        end)
    end
  end
end
