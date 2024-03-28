defmodule Plausible.Stats.Filters.DashboardFilterParser do
  @moduledoc false

  import Plausible.Stats.Filters.Utils
  alias Plausible.Stats.Filters

  @doc """
  This function parses and prefixes the map filter format used by
  the internal React dashboard API
  """
  def parse_and_prefix(filters_map) do
    Enum.reduce(filters_map, %{}, fn {name, val}, new_filters ->
      cond do
        name in Filters.event_props() and name in Filters.visit_props() ->
          new_filters
          |> Map.put("event:" <> name, filter_value(name, val))
          |> Map.put("visit:" <> name, filter_value(name, val))

        name in Filters.visit_props() ->
          Map.put(new_filters, "visit:" <> name, filter_value(name, val))

        name in Filters.event_props() ->
          Map.put(new_filters, "event:" <> name, filter_value(name, val))

        name == "props" ->
          put_parsed_props(new_filters, name, val)

        true ->
          new_filters
      end
    end)
  end

  @spec filter_value(String.t(), String.t()) :: {atom(), String.t() | [String.t()]}
  def filter_value(key, val) do
    {is_negated, val} = parse_negated_prefix(val)
    {is_contains, val} = parse_contains_prefix(val)
    is_list = list_expression?(val)
    is_wildcard = String.contains?(key, ["page", "goal", "hostname"]) && wildcard_expression?(val)
    val = if is_list, do: parse_member_list(val), else: remove_escape_chars(val)
    val = if key == "goal", do: wrap_goal_value(val), else: val

    cond do
      is_negated && is_wildcard && is_list -> {:not_matches_member, val}
      is_negated && is_contains && is_list -> {:not_matches_member, Enum.map(val, &"**#{&1}**")}
      is_wildcard && is_list -> {:matches_member, val}
      is_negated && is_wildcard -> {:does_not_match, val}
      is_negated && is_list -> {:not_member, val}
      is_negated && is_contains -> {:does_not_match, "**" <> val <> "**"}
      is_contains && is_list -> {:matches_member, Enum.map(val, &"**#{&1}**")}
      is_wildcard && is_list -> {:matches_member, val}
      is_negated -> {:is_not, val}
      is_list -> {:member, val}
      is_contains -> {:matches, "**" <> val <> "**"}
      is_wildcard -> {:matches, val}
      true -> {:is, val}
    end
  end

  defp put_parsed_props(new_filters, name, val) do
    Enum.reduce(val, new_filters, fn {prop_key, prop_val}, new_filters ->
      Map.put(new_filters, "event:props:" <> prop_key, filter_value(name, prop_val))
    end)
  end

  defp parse_negated_prefix("!" <> val), do: {true, val}
  defp parse_negated_prefix(val), do: {false, val}

  defp parse_contains_prefix("~" <> val), do: {true, val}
  defp parse_contains_prefix(val), do: {false, val}
end
