defmodule Plausible.Goals.Filters do
  @moduledoc false

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
        type = Plausible.Goal.type(goal)
        dynamic([e], ^goal_condition(type, goal, imported?) or ^dynamic_statement)
      end
    end)
  end

  defp goal_condition(:event, goal, _) do
    dynamic([e], e.name == ^goal.event_name)
  end

  defp goal_condition(:scroll, goal, _) do
    pathname_condition = page_path_condition(goal.page_path, _imported? = false)
    name_condition = dynamic([e], e.name == "pageleave")

    scroll_condition =
      dynamic([e], e.scroll_depth <= 100 and e.scroll_depth >= ^goal.scroll_threshold)

    dynamic([e], ^pathname_condition and ^name_condition and ^scroll_condition)
  end

  defp goal_condition(:page, goal, imported?) do
    pathname_condition = page_path_condition(goal.page_path, imported?)
    name_condition = if imported?, do: true, else: dynamic([e], e.name == "pageview")

    dynamic([e], ^pathname_condition and ^name_condition)
  end

  defp page_path_condition(page_path, imported?) do
    db_field = page_path_db_field(imported?)

    if String.contains?(page_path, "*") do
      dynamic([e], fragment("match(?, ?)", field(e, ^db_field), ^page_regex(page_path)))
    else
      dynamic([e], field(e, ^db_field) == ^page_path)
    end
  end

  def page_path_db_field(true = _imported?), do: :page
  def page_path_db_field(false = _imported?), do: :pathname
end
