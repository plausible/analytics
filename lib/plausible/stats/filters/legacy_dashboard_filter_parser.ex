defmodule Plausible.Stats.Filters.LegacyDashboardFilterParser do
  @moduledoc false

  import Plausible.Stats.Filters.Utils
  alias Plausible.Stats.Filters

  @doc """
  This function parses and prefixes the map filter format used by
  the internal React dashboard API
  """
  def parse_and_prefix(filters_map) do
    Enum.flat_map(filters_map, fn {name, val} ->
      cond do
        name in Filters.visit_props() ->
          [filter_value("visit:" <> name, val)]

        name in Filters.event_props() ->
          [filter_value("event:" <> name, val)]

        name == "props" ->
          parse_props(val)

        true ->
          []
      end
    end)
  end

  def filter_value(key, val) do
    {is_negated, val} = parse_negated_prefix(val)
    {is_contains, val} = parse_contains_prefix(val)
    is_list = list_expression?(val)
    is_wildcard = String.contains?(key, ["page", "hostname"]) && wildcard_expression?(val)
    val = if is_list, do: parse_member_list(val), else: remove_escape_chars(val)

    cond do
      is_negated && is_wildcard && is_list ->
        [:matches_wildcard_not, key, val, %{}]

      is_negated && is_contains && is_list ->
        [:matches_wildcard_not, key, Enum.map(val, &"**#{&1}**"), %{}]

      is_wildcard && is_list ->
        [:matches_wildcard, key, val, %{}]

      is_negated && is_wildcard ->
        [:matches_wildcard_not, key, [val], %{}]

      is_negated && is_list ->
        [:is_not, key, val, %{}]

      is_negated && is_contains ->
        [:matches_wildcard_not, key, ["**" <> val <> "**"], %{}]

      is_negated ->
        [:is_not, key, [val], %{}]

      is_contains && is_list ->
        [:contains, key, val, %{}]

      is_list ->
        [:is, key, val, %{}]

      is_contains ->
        [:contains, key, [val], %{}]

      is_wildcard ->
        [:matches_wildcard, key, [val], %{}]

      true ->
        [:is, key, [val], %{}]
    end
  end

  defp parse_props(val) do
    Enum.map(val, fn {prop_key, prop_val} ->
      filter_value("event:props:" <> prop_key, prop_val)
    end)
  end

  defp parse_negated_prefix("!" <> val), do: {true, val}
  defp parse_negated_prefix(val), do: {false, val}

  defp parse_contains_prefix("~" <> val), do: {true, val}
  defp parse_contains_prefix(val), do: {false, val}
end
