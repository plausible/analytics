defmodule Plausible.Stats.Filters do
  @visit_props [
    "source",
    "referrer",
    "utm_medium",
    "utm_source",
    "utm_campaign",
    "utm_content",
    "utm_term",
    "screen",
    "device",
    "browser",
    "browser_version",
    "os",
    "os_version",
    "country",
    "region",
    "city",
    "entry_page",
    "exit_page"
  ]

  @event_props [
    "name",
    "page",
    "goal"
  ]

  def visit_props() do
    @visit_props
  end

  def add_prefix(query) do
    new_filters =
      Enum.reduce(query.filters, %{}, fn {name, val}, new_filters ->
        cond do
          name in @visit_props ->
            Map.put(new_filters, "visit:" <> name, filter_value(name, val))

          name in @event_props ->
            Map.put(new_filters, "event:" <> name, filter_value(name, val))

          name == "props" ->
            Enum.reduce(val, new_filters, fn {prop_key, prop_val}, new_filters ->
              Map.put(new_filters, "event:props:" <> prop_key, filter_value(name, prop_val))
            end)
        end
      end)

    %Plausible.Stats.Query{query | filters: new_filters}
  end

  @non_escaped_pipe_regex ~r/(?<!\\)\|/
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp filter_value(key, val) do
    {is_negated, val} = parse_negated_prefix(val)
    {is_contains, val} = parse_contains_prefix(val)
    is_list = Regex.match?(@non_escaped_pipe_regex, val)
    is_wildcard = String.contains?(key, ["page", "goal"]) && String.match?(val, ~r/\*/)
    val = if is_list, do: parse_member_list(val), else: val
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

  defp parse_negated_prefix("!" <> val), do: {true, val}
  defp parse_negated_prefix(val), do: {false, val}

  defp parse_contains_prefix("~" <> val), do: {true, val}
  defp parse_contains_prefix(val), do: {false, val}

  defp parse_member_list(raw_value) do
    raw_value
    |> String.split(@non_escaped_pipe_regex)
    |> Enum.map(&remove_escape_chars/1)
  end

  defp remove_escape_chars(value) do
    String.replace(value, "\\|", "|")
  end

  defp wrap_goal_value(goals) when is_list(goals), do: Enum.map(goals, &wrap_goal_value/1)
  defp wrap_goal_value("Visit " <> page), do: {:page, page}
  defp wrap_goal_value(event), do: {:event, event}
end
