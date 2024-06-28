defmodule Plausible.Stats.Filters.Utils do
  @moduledoc """
  Contains utility functions shared between `LegacyDashboardFilterParser`
  and `StatsAPIFilterParser`.
  """

  @non_escaped_pipe_regex ~r/(?<!\\)\|/

  def list_expression?(expression) do
    Regex.match?(@non_escaped_pipe_regex, expression)
  end

  def wildcard_expression?(expression) do
    String.contains?(expression, "*")
  end

  def parse_member_list(raw_value) do
    raw_value
    |> String.split(@non_escaped_pipe_regex)
    |> Enum.map(&remove_escape_chars/1)
  end

  def remove_escape_chars(value) do
    String.replace(value, "\\|", "|")
  end

  @doc """
  Wraps the given goal filter into a tuple where the first element
  represents the goal type (i.e. `page` or `event`), and the second
  element is either the page path or the event name.

  Given a list of goal filter values, wraps all values based on the
  same logic.

  ## Examples

    iex> Plausible.Stats.Filters.Utils.wrap_goal_value("Visit /register")
    {:page, "/register"}

    iex> Plausible.Stats.Filters.Utils.wrap_goal_value("Signup")
    {:event, "Signup"}

    iex> Plausible.Stats.Filters.Utils.wrap_goal_value(["Signup", "Visit /register"])
    [{:event, "Signup"}, {:page, "/register"}]
  """
  def wrap_goal_value(goals) when is_list(goals), do: Enum.map(goals, &wrap_goal_value/1)
  def wrap_goal_value("Visit " <> page), do: {:page, page}
  def wrap_goal_value(event), do: {:event, event}

  @doc """
  Does the opposite to `wrap_goal_value`, turning the `{:page, path}`
  and `{:event, name}` tuples into strings. Similarly, when given a
  list, maps all the list elements into strings with the same logic.

  ## Examples

    iex> Plausible.Stats.Filters.Utils.unwrap_goal_value({:page, "/register"})
    "Visit /register"

    iex> Plausible.Stats.Filters.Utils.unwrap_goal_value({:event, "Signup"})
    "Signup"

    iex> Plausible.Stats.Filters.Utils.unwrap_goal_value([{:event, "Signup"}, {:page, "/register"}])
    ["Signup", "Visit /register"]
  """
  def unwrap_goal_value(goals) when is_list(goals), do: Enum.map(goals, &unwrap_goal_value/1)
  def unwrap_goal_value({:page, page}), do: "Visit " <> page
  def unwrap_goal_value({:event, event}), do: event

  def split_goals(goals) do
    Enum.split_with(goals, fn {type, _} -> type == :event end)
  end

  def split_goals_query_expressions(goals) do
    {event_goals, pageview_goals} = split_goals(goals)
    events = Enum.map(event_goals, fn {_, event} -> event end)

    page_regexes =
      Enum.map(pageview_goals, fn {_, path} -> Plausible.Stats.Base.page_regex(path) end)

    {events, page_regexes}
  end
end
