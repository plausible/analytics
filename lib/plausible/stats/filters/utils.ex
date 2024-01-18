defmodule Plausible.Stats.Filters.Utils do
  @moduledoc """
  Contains utility functions shared between `DashboardFilterParser`
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

  def wrap_goal_value(goals) when is_list(goals), do: Enum.map(goals, &wrap_goal_value/1)
  def wrap_goal_value("Visit " <> page), do: {:page, page}
  def wrap_goal_value(event), do: {:event, event}
end
