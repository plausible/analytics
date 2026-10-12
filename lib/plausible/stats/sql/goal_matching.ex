defmodule Plausible.Stats.SQL.GoalMatching do
  @moduledoc """
  Builds the matching goal indices for an `event:goal` breakdown.

  Event names and exact page paths use lookups when no custom properties
  are required. Other goals use regex matching and additional filters.

  Returned indices are 1-based positions in
  `query.preloaded_goals.matching_toplevel_filters`, used by QueryRunner
  to identify the matching goals.
  """

  import Ecto.Query

  alias Plausible.Goal
  alias Plausible.Stats.Goals

  @doc """
  An `Array(UInt64)` expression of the indices of the goals the event completes.
  """
  def completed_goals(query) do
    %{by_name: by_name, by_pathname: by_pathname, scanned: scanned} =
      partition(query.preloaded_goals.matching_toplevel_filters)

    [
      lookup(dynamic([e], e.name), by_name),
      lookup(dynamic([e], e.pathname), by_pathname)
      |> only_if(dynamic([e], e.name == "pageview")),
      scan(scanned)
    ]
    |> Enum.reject(&is_nil/1)
    |> concat()
  end

  # Groups goals, with their indices, by how they are matched. The unique indexes
  # on goals keep each event name and exact page path to one goal without custom
  # props, so a lookup by either finds at most one goal.
  defp partition(goals) do
    keyed = for {goal, index} <- Enum.with_index(goals, 1), do: {lookup_key(goal), goal, index}

    %{
      by_name: for({{:name, name}, _goal, index} <- keyed, do: {name, index}),
      by_pathname: for({{:pathname, path}, _goal, index} <- keyed, do: {path, index}),
      scanned: for({nil, goal, index} <- keyed, do: {goal, index})
    }
  end

  defp lookup_key(goal) do
    cond do
      Goal.has_custom_props?(goal) -> nil
      Goal.type(goal) == :event -> {:name, goal.event_name}
      Goal.type(goal) == :page and exact_path?(goal.page_path) -> {:pathname, goal.page_path}
      true -> nil
    end
  end

  # Filters.Utils.page_regex/1 turns `*` into wildcards and `|` into regex
  # alternation, so paths with either aren't matched exactly
  defp exact_path?(page_path), do: not String.contains?(page_path, ["*", "|"])

  defp lookup(_value, []), do: nil

  # The goal whose key is `value`, if any. transform() is a hash lookup, while
  # has() on a constant array would scan it on every row.
  defp lookup(value, table) do
    {keys, goal_indices} = Enum.unzip(table)

    dynamic(
      fragment(
        "arrayFilter(i -> i != 0, [transform(?, ?, CAST(? AS Array(UInt64)), toUInt64(0))])",
        ^value,
        type(^keys, {:array, :string}),
        type(^goal_indices, {:array, :integer})
      )
    )
  end

  defp scan([]), do: nil

  defp scan(indexed_goals) do
    {goals, goal_indices} = Enum.unzip(indexed_goals)
    expected_names = Enum.map(goals, &Goals.expected_event_name/1)
    distinct_names = Enum.uniq(expected_names)

    dynamic(
      [e],
      fragment(
        "multiMatchAllIndices(?, ?)",
        e.pathname,
        type(^Enum.map(goals, &Goals.pathname_regex/1), {:array, :string})
      )
    )
    |> keep_expected_events(goals, expected_names, distinct_names)
    |> keep_matching_custom_props(goals)
    |> to_goal_indices(goal_indices)
    |> only_if(
      dynamic([e], fragment("has(?, ?)", type(^distinct_names, {:array, :string}), e.name))
    )
  end

  # The outer name guard is sufficient when all scanned goals expect the same name.
  # Omit the depth check when there are no scroll goals.
  # The upper bound excludes the missing-depth sentinel, 255.
  defp keep_expected_events(positions, goals, expected_names, distinct_names) do
    name_check =
      if length(distinct_names) > 1 do
        dynamic([e], fragment("?[i] = ?", type(^expected_names, {:array, :string}), e.name))
      end

    threshold_check =
      if Enum.any?(goals, &(Goal.type(&1) == :scroll)) do
        thresholds = Enum.map(goals, & &1.scroll_threshold)

        dynamic(
          [e],
          fragment(
            "(? BETWEEN ?[i] AND 100)",
            e.scroll_depth,
            type(^thresholds, {:array, :integer})
          )
        )
      end

    keep_positions(positions, Enum.reject([name_check, threshold_check], &is_nil/1))
  end

  # Check custom properties only for positions that survived the earlier filters.
  # Omit meta.* references entirely when no scanned goal has custom properties.
  defp keep_matching_custom_props(positions, goals) do
    if Enum.any?(goals, &Goal.has_custom_props?/1) do
      {keys, values} =
        goals
        |> Enum.map(&Enum.unzip(&1.custom_props))
        |> Enum.unzip()

      props_check =
        dynamic(
          [e],
          fragment(
            "(empty(?[i]) OR arrayAll((k, v) -> ?[indexOf(?, k)] = v, ?[i], ?[i]))",
            type(^keys, {:array, {:array, :string}}),
            field(e, :"meta.value"),
            field(e, :"meta.key"),
            type(^keys, {:array, {:array, :string}}),
            type(^values, {:array, {:array, :string}})
          )
        )

      keep_positions(positions, [props_check])
    else
      positions
    end
  end

  # Each check references `i`, bound here to a 1-based position in the scanned goals.
  defp keep_positions(positions, []), do: positions

  defp keep_positions(positions, checks) do
    condition = Enum.reduce(checks, fn check, acc -> dynamic(^acc and ^check) end)
    dynamic(fragment("arrayFilter(i -> ?, ?)", ^condition, ^positions))
  end

  defp to_goal_indices(positions, goal_indices) do
    dynamic(
      fragment(
        "arrayMap(i -> CAST(? AS Array(UInt64))[i], ?)",
        type(^goal_indices, {:array, :integer}),
        ^positions
      )
    )
  end

  defp only_if(nil, _condition), do: nil

  defp only_if(goals, condition) do
    dynamic(fragment("if(?, ?, CAST([] AS Array(UInt64)))", ^condition, ^goals))
  end

  defp concat([]), do: dynamic(fragment("CAST([] AS Array(UInt64))"))
  defp concat([goals]), do: goals
  defp concat([a, b]), do: dynamic(fragment("arrayConcat(?, ?)", ^a, ^b))
  defp concat([a, b, c]), do: dynamic(fragment("arrayConcat(?, ?, ?)", ^a, ^b, ^c))
end
