defmodule Plausible.Goals.Filters do
  @moduledoc false

  import Ecto.Query
  import Plausible.Stats.Filters.Utils, only: [page_regex: 1]

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
        query.preloaded_goals
        |> filter_preloaded(filter, clause)
        |> build_condition(imported?)

      dynamic([e], ^condition or ^dynamic_statement)
    end)
  end

  def preload_needed_goals(site, filters) do
    goals = Plausible.Goals.for_site(site)

    Enum.reduce(filters, goals, fn
      [_, "event:goal" | _] = filter, goals ->
        goals_matching_any_clause(goals, filter)

      _filter, goals ->
        goals
    end)
  end

  defp filter_preloaded(preloaded_goals, filter, clause) do
    Enum.filter(preloaded_goals, fn goal -> matches?(goal, filter, clause) end)
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
      case goal do
        nil ->
          dynamic([e], ^dynamic_statement)

        %Plausible.Goal{event_name: event_name} when is_binary(event_name) ->
          dynamic([e], e.name == ^event_name or ^dynamic_statement)

        %Plausible.Goal{page_path: page_path} when is_binary(page_path) ->
          dynamic([e], ^page_filter_condition(page_path, imported?) or ^dynamic_statement)
      end
    end)
  end

  defp page_filter_condition(page_path, imported?) do
    db_field = page_path_db_field(imported?)

    page_condition =
      if String.contains?(page_path, "*") do
        dynamic([e], fragment("match(?, ?)", field(e, ^db_field), ^page_regex(page_path)))
      else
        dynamic([e], field(e, ^db_field) == ^page_path)
      end

    if imported? do
      dynamic([e], ^page_condition)
    else
      dynamic([e], ^page_condition and e.name == "pageview")
    end
  end

  def page_path_db_field(true = _imported?), do: :page
  def page_path_db_field(false = _imported?), do: :pathname
end
