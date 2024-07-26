defmodule Plausible.Goals.Filters do
  @moduledoc false

  import Ecto.Query
  import Plausible.Stats.Filters.Utils, only: [page_regex: 1]
  alias Plausible.Stats.Sql

  @doc """
  Translates an event:goal filter into SQL. Similarly to other `add_filter` clauses in
  `Plausible.Stats.SQL.WhereBuilder`, returns an `Ecto.Query.dynamic` expression.

  Compared to other dimensions, filtering by goals works differently. First, we expect
  all goals to be preloaded into the query - this list of goals is what actually gets
  filtered by `operator` and `clauses`.

  With the resulting filtered list of goals, we build conditions for whether that goal
  was completed or not, and join those conditions with a logical OR.
  """
  def add_filter(query, [operation, "event:goal", clauses]) when operation in [:is] do
    Enum.map(clauses, fn clause ->
      query.preloaded_goals
      |> filter_preloaded(operation, clause)
      |> build_condition()
    end)
    |> Sql.Util.or_join()
  end

  defp filter_preloaded(preloaded_goals, operation, clause) when operation in [:is, :contains] do
    Enum.filter(preloaded_goals, fn goal ->
      case operation do
        :is ->
          Plausible.Goal.display_name(goal) == clause
      end
    end)
  end

  defp build_condition(filtered_goals) do
    filtered_goals
    |> Enum.map(fn
      nil ->
        false

      %Plausible.Goal{event_name: event_name} when is_binary(event_name) ->
        dynamic([e], e.name == ^event_name)

      %Plausible.Goal{page_path: page_path} when is_binary(page_path) ->
        dynamic([e], ^page_filter_condition(page_path) and e.name == "pageview")
    end)
    |> Sql.Util.or_join()
  end

  defp page_filter_condition(page_path) do
    if String.contains?(page_path, "*") do
      dynamic([e], fragment("match(?, ?)", e.pathname, ^page_regex(page_path)))
    else
      dynamic([e], e.pathname == ^page_path)
    end
  end
end
