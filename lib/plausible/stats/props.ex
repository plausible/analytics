defmodule Plausible.Stats.Props do
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base

  def props(site, query) do
    prop_filter =
      Enum.find(query.filters, fn {key, _} -> String.starts_with?(key, "event:props:") end)

    if prop_filter do
      {key, val} = prop_filter

      if val == "(none)" do
        goal = query.filters["goal"]
        %{goal => [key]}
      else
        ClickhouseRepo.all(
          from [e, meta: meta] in base_event_query(site, query),
            select: {e.name, meta.key},
            distinct: true
        )
        |> Enum.reduce(%{}, fn {goal_name, meta_key}, acc ->
          Map.update(acc, goal_name, [meta_key], fn list -> [meta_key | list] end)
        end)
      end
    else
      ClickhouseRepo.all(
        from e in base_event_query(site, query),
          inner_lateral_join: meta in fragment("meta as m"),
          select: {e.name, meta.key},
          distinct: true
      )
      |> Enum.reduce(%{}, fn {goal_name, meta_key}, acc ->
        Map.update(acc, goal_name, [meta_key], fn list -> [meta_key | list] end)
      end)
    end
  end
end
