defmodule Plausible.Stats.Goals do
  @moduledoc """
  Stats code related to filtering and grouping by goals.
  """

  import Ecto.Query
  import Plausible.Stats.Filters.Utils, only: [page_regex: 1]

  alias Plausible.Stats.Filters

  @doc """
  Preloads goals data if needed for query-building and related work.
  """
  def preload_needed_goals(site, dimensions, filters) do
    if Enum.member?(dimensions, "event:goal") or
         Filters.filtering_on_dimension?(filters, "event:goal") do
      goals = Plausible.Goals.for_site(site)

      %{
        # When grouping by event:goal, later pipeline needs to know which goals match filters exactly.
        # This can affect both calculations whether all goals have the same revenue currency and
        # whether we should skip imports.
        matching_toplevel_filters: goals_matching_toplevel_filters(goals, filters),
        all: goals
      }
    else
      %{
        all: [],
        matching_toplevel_filters: []
      }
    end
  end

  @doc """
  Translates an event:goal filter into SQL. Similarly to other `add_filter` clauses in
  `Plausible.Stats.SQL.WhereBuilder`, returns an `Ecto.Query.dynamic` expression.

  Compared to other dimensions, filtering by goals works differently. First, we expect
  all goals to be preloaded into the query - this list of goals is what actually gets
  filtered by `operator` and `clauses`.

  With the resulting filtered list of goals, we build conditions for whether that goal
  was completed or not, and join those conditions with a logical OR.

  ### Options

  * `imported?` - when `true`, builds conditions on the `page` db field rather than
    `pathname`, and also skips the `e.name == "pageview"` check.
  """
  def add_filter(query, [operation, "event:goal", clauses | _] = filter, opts \\ [])
      when operation in [:is, :contains] do
    imported? = Keyword.get(opts, :imported?, false)

    Enum.reduce(clauses, false, fn clause, dynamic_statement ->
      condition =
        query.preloaded_goals.all
        |> filter_preloaded(filter, clause)
        |> build_condition(imported?)

      dynamic([e], ^condition or ^dynamic_statement)
    end)
  end

  @type goal_join_data() :: %{
          indices: [non_neg_integer()],
          types: [String.t()],
          event_names_imports: [String.t()],
          event_names_by_type: [String.t()],
          page_regexes: [String.t()],
          scroll_thresholds: [non_neg_integer()],
          custom_props_keys: [[String.t()]],
          custom_props_values: [[String.t()]]
        }

  @doc """
  Returns data needed to perform a GROUP BY on goals in an ecto query.
  """
  @spec goal_join_data(Plausible.Stats.Query.t()) :: goal_join_data()
  def goal_join_data(query) do
    goals = query.preloaded_goals.matching_toplevel_filters

    goals
    |> Enum.with_index(1)
    |> Enum.reduce(
      %{
        indices: [],
        types: [],
        event_names_imports: [],
        event_names_by_type: [],
        page_regexes: [],
        scroll_thresholds: [],
        custom_props_keys: [],
        custom_props_values: []
      },
      fn {goal, idx}, acc ->
        goal_type = Plausible.Goal.type(goal)
        {prop_keys, prop_values} = Enum.unzip(goal.custom_props)

        %{
          indices: [idx | acc.indices],
          types: [to_string(goal_type) | acc.types],
          # This will contain "" for non-event goals
          event_names_imports: [to_string(goal.event_name) | acc.event_names_imports],
          event_names_by_type: [event_name_by_type(goal_type, goal) | acc.event_names_by_type],
          # Event goals are considered to match everything for the sake of efficient queries in query_builder.ex
          # See also Plausible.Stats.SQL.Expression.event_goal_join/1
          page_regexes: [page_regex_for_goal(goal_type, goal) | acc.page_regexes],
          scroll_thresholds: [goal.scroll_threshold | acc.scroll_thresholds],
          custom_props_keys: [prop_keys | acc.custom_props_keys],
          custom_props_values: [prop_values | acc.custom_props_values]
        }
      end
    )
    |> Enum.map(fn {key, list} -> {key, Enum.reverse(list)} end)
    |> Map.new()
  end

  defp event_name_by_type(:event, goal), do: goal.event_name
  defp event_name_by_type(:page, _goal), do: "pageview"
  defp event_name_by_type(:scroll, _goal), do: "engagement"

  defp page_regex_for_goal(:event, _goal), do: ".?"
  defp page_regex_for_goal(:page, goal), do: Filters.Utils.page_regex(goal.page_path)
  defp page_regex_for_goal(:scroll, goal), do: Filters.Utils.page_regex(goal.page_path)

  def toplevel_scroll_goal_filters?(query) do
    goal_filters? =
      Enum.any?(query.filters, fn
        [_, "event:goal", _] -> true
        _ -> false
      end)

    any_scroll_goals_preloaded? =
      query.preloaded_goals.matching_toplevel_filters
      |> Enum.any?(fn goal -> Plausible.Goal.type(goal) == :scroll end)

    goal_filters? and any_scroll_goals_preloaded?
  end

  defp filter_preloaded(goals, filter, clause) do
    Enum.filter(goals, fn goal -> matches?(goal, filter, clause) end)
  end

  defp goals_matching_toplevel_filters(goals, filters) do
    Enum.reduce(filters, goals, fn
      [_, "event:goal" | _] = filter, goals ->
        goals_matching_any_clause(goals, filter)

      _filter, goals ->
        goals
    end)
  end

  defp goals_matching_any_clause(goals, [_, _, clauses | _] = filter) do
    goals
    |> Enum.filter(fn goal ->
      Enum.any?(clauses, fn clause -> matches?(goal, filter, clause) end)
    end)
  end

  defp matches?(goal, [operation | _rest] = filter, clause) do
    goal_name =
      goal
      |> Plausible.Goal.display_name()
      |> mod(filter)

    clause = mod(clause, filter)

    case operation do
      :is ->
        goal_name == clause

      :contains ->
        String.contains?(goal_name, clause)
    end
  end

  defp mod(str, filter) do
    case filter do
      [_, _, _, %{case_sensitive: false}] -> String.downcase(str)
      _ -> str
    end
  end

  defp build_condition(filtered_goals, imported?) do
    Enum.reduce(filtered_goals, false, fn goal, dynamic_statement ->
      if is_nil(goal) do
        dynamic([e], ^dynamic_statement)
      else
        dynamic([e], ^goal_condition(goal, imported?) or ^dynamic_statement)
      end
    end)
  end

  def goal_condition(goal, imported? \\ false) do
    type = Plausible.Goal.type(goal)
    goal_condition(type, goal, imported?)
  end

  defp goal_condition(:event, goal, _) do
    name_condition = dynamic([e], e.name == ^goal.event_name)

    if Plausible.Goal.has_custom_props?(goal) do
      custom_props_condition = build_custom_props_condition(goal.custom_props)
      dynamic([e], ^name_condition and ^custom_props_condition)
    else
      name_condition
    end
  end

  defp goal_condition(:scroll, goal, false = _imported?) do
    pathname_condition = page_path_condition(goal.page_path, _imported? = false)
    name_condition = dynamic([e], e.name == "engagement")

    scroll_condition =
      dynamic([e], e.scroll_depth <= 100 and e.scroll_depth >= ^goal.scroll_threshold)

    base_condition = dynamic([e], ^pathname_condition and ^name_condition and ^scroll_condition)

    if Plausible.Goal.has_custom_props?(goal) do
      custom_props_condition = build_custom_props_condition(goal.custom_props)
      dynamic([e], ^base_condition and ^custom_props_condition)
    else
      base_condition
    end
  end

  defp goal_condition(:page, goal, true = _imported?) do
    page_path_condition(goal.page_path, _imported? = true)
  end

  defp goal_condition(:page, goal, false = _imported?) do
    name_condition = dynamic([e], e.name == "pageview")
    pathname_condition = page_path_condition(goal.page_path, _imported? = false)
    base_condition = dynamic([e], ^pathname_condition and ^name_condition)

    if Plausible.Goal.has_custom_props?(goal) do
      custom_props_condition = build_custom_props_condition(goal.custom_props)
      dynamic([e], ^base_condition and ^custom_props_condition)
    else
      base_condition
    end
  end

  defp page_path_condition(page_path, imported?) do
    db_field = page_path_db_field(imported?)

    if String.contains?(page_path, "*") do
      dynamic([e], fragment("match(?, ?)", field(e, ^db_field), ^page_regex(page_path)))
    else
      dynamic([e], field(e, ^db_field) == ^page_path)
    end
  end

  defp build_custom_props_condition(custom_props) do
    Enum.reduce(custom_props, true, fn {prop_key, prop_value}, acc ->
      condition =
        dynamic(
          [e],
          fragment(
            "?[indexOf(?, ?)] = ?",
            field(e, :"meta.value"),
            field(e, :"meta.key"),
            ^prop_key,
            ^prop_value
          )
        )

      dynamic([e], ^acc and ^condition)
    end)
  end

  def page_path_db_field(true = _imported?), do: :page
  def page_path_db_field(false = _imported?), do: :pathname
end
