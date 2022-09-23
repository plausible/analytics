defmodule Plausible.Stats.FilterParser do
  def parse_filters(%{"filters" => filters}) when is_binary(filters) do
    case Jason.decode(filters) do
      {:ok, parsed} -> parsed
      {:error, err} -> parse_filter_expression(err.data)
    end
  end

  def parse_filters(%{"filters" => filters}) when is_map(filters), do: filters
  def parse_filters(_), do: %{}

  defp parse_filter_expression(str) do
    filters = String.split(str, ";")

    Enum.map(filters, &parse_single_filter/1)
    |> Enum.into(%{})
  end

  @non_escaped_pipe_regex ~r/(?<!\\)\|/
  defp parse_single_filter(str) do
    [key, raw_value] =
      String.trim(str)
      |> String.split(["==", "!="], trim: true)
      |> Enum.map(&String.trim/1)

    is_negated = String.contains?(str, "!=")
    is_list = Regex.match?(@non_escaped_pipe_regex, raw_value)
    is_wildcard = String.contains?(raw_value, "*")

    final_value = remove_escape_chars(raw_value)

    cond do
      key == "event:goal" -> {key, parse_goal_filter(final_value)}
      is_wildcard && is_negated -> {key, {:does_not_match, final_value}}
      is_wildcard -> {key, {:matches, final_value}}
      is_list -> {key, {:member, parse_member_list(raw_value)}}
      is_negated -> {key, {:is_not, final_value}}
      true -> {key, {:is, final_value}}
    end
  end

  defp parse_goal_filter("Visit " <> page), do: {:is, :page, page}
  defp parse_goal_filter(event), do: {:is, :event, event}

  defp remove_escape_chars(value) do
    String.replace(value, "\\|", "|")
  end

  defp parse_member_list(raw_value) do
    raw_value
    |> String.split(@non_escaped_pipe_regex)
    |> Enum.map(&remove_escape_chars/1)
  end
end
