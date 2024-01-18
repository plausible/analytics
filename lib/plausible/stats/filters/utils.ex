defmodule Plausible.Stats.Filters.Utils do
  @moduledoc """
  Contains utility functions shared between `DashboardFilterParser`
  and `StatsAPIFilterParser`.
  """

  @non_escaped_pipe_regex ~r/(?<!\\)\|/

  def list_expression?(expression) do
    Regex.match?(@non_escaped_pipe_regex, expression)
  end

  def parse_member_list(raw_value) do
    raw_value
    |> String.split(@non_escaped_pipe_regex)
    |> Enum.map(&remove_escape_chars/1)
  end

  def remove_escape_chars(value) do
    String.replace(value, "\\|", "|")
  end
end
