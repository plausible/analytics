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
    "page"
  ]

  def visit_props() do
    @visit_props
  end

  def add_prefix(query) do
    new_filters =
      Enum.reduce(query.filters, %{}, fn {name, val}, new_filters ->
        cond do
          name == "goal" ->
            filter =
              case val do
                "Visit " <> page ->
                  {filter_type, filter_val} = filter_value(name, page)
                  {filter_type, :page, filter_val}

                event ->
                  {:is, :event, event}
              end

            Map.put(new_filters, "event:goal", filter)

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
  defp filter_value(key, val) do
    {is_negated, val} = parse_negated_prefix(val)
    {is_contains, val} = parse_contains_prefix(val)
    is_list = Regex.match?(@non_escaped_pipe_regex, val)
    is_wildcard = String.contains?(key, ["page", "goal"]) && String.match?(val, ~r/\*/)

    cond do
      is_negated && is_wildcard -> {:does_not_match, val}
      is_negated -> {:is_not, val}
      is_list -> {:member, parse_member_list(val)}
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
  end
end
