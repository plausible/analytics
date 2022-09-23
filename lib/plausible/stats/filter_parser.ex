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

  defp parse_single_filter(str) do
    [key, val] =
      String.trim(str)
      |> String.split(["==", "!="], trim: true)
      |> Enum.map(&String.trim/1)

    is_negated = String.contains?(str, "!=")
    is_list = String.contains?(val, "|")
    is_wildcard = String.contains?(val, "*")

    cond do
      key == "event:goal" -> {key, parse_goal_filter(val)}
      is_wildcard && is_negated -> {key, {:does_not_match, val}}
      is_wildcard -> {key, {:matches, val}}
      is_list -> {key, {:member, String.split(val, "|")}}
      is_negated -> {key, {:is_not, val}}
      true -> {key, {:is, val}}
    end
  end

  defp parse_goal_filter("Visit " <> page), do: {:is, :page, page}
  defp parse_goal_filter(event), do: {:is, :event, event}
end
