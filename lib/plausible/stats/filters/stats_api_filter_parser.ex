defmodule Plausible.Stats.Filters.StatsAPIFilterParser do
  @moduledoc false

  alias Plausible.Stats.Filters

  @doc """
  This function parses the filter expression given as a string.
  This filtering format is used by the public Stats API.
  """
  def parse_filter_expression(str) do
    filters = String.split(str, ";")

    Enum.map(filters, &parse_single_filter/1)
    |> Enum.reject(fn parsed -> parsed == :error end)
    |> Enum.into(%{})
  end

  defp parse_single_filter(str) do
    case to_kv(str) do
      [key, raw_value] ->
        is_negated = String.contains?(str, "!=")
        is_list = Regex.match?(Filters.non_escaped_pipe_regex(), raw_value)
        is_wildcard = String.contains?(raw_value, "*")

        final_value = remove_escape_chars(raw_value)

        cond do
          key == "event:goal" -> {key, parse_goal_filter(final_value)}
          is_wildcard && is_negated -> {key, {:does_not_match, raw_value}}
          is_wildcard -> {key, {:matches, raw_value}}
          is_list -> {key, {:member, parse_member_list(raw_value)}}
          is_negated -> {key, {:is_not, final_value}}
          true -> {key, {:is, final_value}}
        end
        |> reject_invalid_country_codes()

      _ ->
        :error
    end
  end

  defp reject_invalid_country_codes({"visit:country", {_, code_or_codes}} = filter) do
    code_or_codes
    |> List.wrap()
    |> Enum.reduce_while(filter, fn
      value, _ when byte_size(value) == 2 -> {:cont, filter}
      _, _ -> {:halt, :error}
    end)
  end

  defp reject_invalid_country_codes(filter), do: filter

  defp to_kv(str) do
    str
    |> String.trim()
    |> String.split(["==", "!="], trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp parse_goal_filter("Visit " <> page), do: {:is, {:page, page}}
  defp parse_goal_filter(event), do: {:is, {:event, event}}

  defp remove_escape_chars(value) do
    String.replace(value, "\\|", "|")
  end

  defp parse_member_list(raw_value) do
    raw_value
    |> String.split(Filters.non_escaped_pipe_regex())
    |> Enum.map(&remove_escape_chars/1)
  end
end
