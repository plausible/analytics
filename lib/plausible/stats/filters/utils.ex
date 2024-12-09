defmodule Plausible.Stats.Filters.Utils do
  @moduledoc false

  def split_goals(goals) do
    Enum.split_with(goals, fn goal -> Plausible.Goal.type(goal) == :event end)
  end

  def split_goals_query_expressions(goals) do
    {event_goals, pageview_goals} = split_goals(goals)
    events = Enum.map(event_goals, fn goal -> goal.event_name end)

    page_regexes =
      Enum.map(pageview_goals, fn goal -> page_regex(goal.page_path) end)

    {events, page_regexes}
  end

  def page_regex(expr) do
    escaped =
      expr
      |> Regex.escape()
      |> String.replace("\\|", "|")
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", ".*")

    "^#{escaped}$"
  end
end
