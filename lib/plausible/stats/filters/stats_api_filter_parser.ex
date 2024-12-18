defmodule Plausible.Stats.Filters.StatsAPIFilterParser do
  @moduledoc false

  @non_escaped_pipe_regex ~r/(?<!\\)\|/

  @doc """
  This function parses the filter expression given as a string.
  This filtering format is used by the public Stats API.
  """
  def parse_filter_expression(str) do
    filters = String.split(str, ";")

    Enum.map(filters, &parse_single_filter/1)
    |> Enum.reject(fn parsed -> parsed == :error end)
  end

  defp parse_single_filter(str) do
    case to_kv(str) do
      ["event:goal" = key, raw_value] ->
        parse_goal_filter(key, raw_value)

      [key, raw_value] ->
        is_negated? = String.contains?(str, "!=")
        is_list? = list_expression?(raw_value)
        is_wildcard? = wildcard_expression?(raw_value)

        final_value = remove_escape_chars(raw_value)

        cond do
          is_wildcard? && is_negated? -> [:matches_wildcard_not, key, [raw_value]]
          is_wildcard? -> [:matches_wildcard, key, [raw_value]]
          is_list? -> [:is, key, parse_member_list(raw_value)]
          is_negated? -> [:is_not, key, [final_value]]
          true -> [:is, key, [final_value]]
        end
        |> reject_invalid_country_codes()

      _ ->
        :error
    end
  end

  defp reject_invalid_country_codes([_op, "visit:country", code_or_codes | _rest] = filter) do
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

  defp parse_goal_filter(key, value) do
    is_list? = list_expression?(value)

    value =
      if is_list? do
        parse_member_list(value)
      else
        remove_escape_chars(value)
      end

    [:is, key, List.wrap(value)]
  end

  defp list_expression?(expression) do
    Regex.match?(@non_escaped_pipe_regex, expression)
  end

  defp wildcard_expression?(expression) do
    String.contains?(expression, "*")
  end

  defp parse_member_list(raw_value) do
    raw_value
    |> String.split(@non_escaped_pipe_regex)
    |> Enum.map(&remove_escape_chars/1)
  end

  defp remove_escape_chars(value) do
    String.replace(value, "\\|", "|")
  end
end
