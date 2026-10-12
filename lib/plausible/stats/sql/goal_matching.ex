defmodule Plausible.Stats.SQL.GoalMatching do
  @moduledoc """
  Builds the SQL expression that lists the goals an event completes, for
  breaking down by `event:goal`.

  An event completes a goal when its pathname matches the goal's pathname regex
  (event goals match any pathname), its name is the one the goal expects, its
  scroll depth reaches the goal's threshold and it has all of the goal's custom
  props.

  Goals are identified by their 1-based index in
  `query.preloaded_goals.matching_toplevel_filters`, which
  `Plausible.Stats.QueryRunner` maps back to the goals.
  """

  import Ecto.Query

  alias Plausible.Goal
  alias Plausible.Stats.Goals

  @doc """
  An array expression of the indices of the goals the event completes.
  """
  def completed_goals(query) do
    goals = query.preloaded_goals.matching_toplevel_filters

    regexes = Enum.map(goals, &Goals.pathname_regex/1)
    expected_names = Enum.map(goals, &Goals.expected_event_name/1)
    thresholds = Enum.map(goals, & &1.scroll_threshold)
    indices = Enum.to_list(1..length(goals)//1)

    if Enum.any?(goals, &Goal.has_custom_props?/1) do
      {keys, values} =
        goals
        |> Enum.map(&Enum.unzip(&1.custom_props))
        |> Enum.unzip()

      dynamic(
        [e],
        fragment(
          """
          arrayIntersect(
            multiMatchAllIndices(?, ?),
            arrayMap(
              (expected_name, threshold, index, custom_props_keys, custom_props_values) -> if(
                expected_name = ? and ? between threshold and 100 and
                (empty(custom_props_keys) OR arrayAll((k, v) -> ?[indexOf(?, k)] = v, custom_props_keys, custom_props_values)),
                index, -1
              ),
              ?,
              ?,
              ?,
              ?,
              ?
            )
          )
          """,
          e.pathname,
          type(^regexes, {:array, :string}),
          e.name,
          e.scroll_depth,
          field(e, :"meta.value"),
          field(e, :"meta.key"),
          type(^expected_names, {:array, :string}),
          type(^thresholds, {:array, :integer}),
          type(^indices, {:array, :integer}),
          type(^keys, {:array, {:array, :string}}),
          type(^values, {:array, {:array, :string}})
        )
      )
    else
      # Leaves out meta.key and meta.value, so ClickHouse doesn't read those
      # expensive Array(String) columns
      dynamic(
        [e],
        fragment(
          """
          arrayIntersect(
            multiMatchAllIndices(?, ?),
            arrayMap(
              (expected_name, threshold, index) -> if(
                expected_name = ? and ? between threshold and 100,
                index, -1
              ),
              ?,
              ?,
              ?
            )
          )
          """,
          e.pathname,
          type(^regexes, {:array, :string}),
          e.name,
          e.scroll_depth,
          type(^expected_names, {:array, :string}),
          type(^thresholds, {:array, :integer}),
          type(^indices, {:array, :integer})
        )
      )
    end
  end
end
