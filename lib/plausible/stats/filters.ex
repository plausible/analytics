defmodule Plausible.Stats.Filters do
  @visit_props [
    "source",
    "referrer",
    "utm_medium",
    "utm_source",
    "utm_campaign",
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
          name == "country" ->
            {filter_type, filter_val} = filter_value(name, val)
            new_val = Plausible.Stats.CountryName.to_alpha2(filter_val)
            Map.put(new_filters, "visit:country", {filter_type, new_val})

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

          name in (@visit_props ++ ["goal"]) ->
            Map.put(new_filters, "visit:" <> name, filter_value(name, val))

          name in @event_props ->
            Map.put(new_filters, "event:" <> name, filter_value(name, val))

          name == "props" ->
            Enum.reduce(val, new_filters, fn {prop_key, prop_val}, new_filters ->
              Map.put(new_filters, "event:props:" <> prop_key, {:is, prop_val})
            end)
        end
      end)

    new_filters =
      case new_filters["event:goal"] do
        nil -> Map.put(new_filters, "event:name", {:is, "pageview"})
        _ -> new_filters
      end

    %Plausible.Stats.Query{query | filters: new_filters}
  end

  defp filter_value(key, "!" <> val) do
    if String.contains?(key, ["page", "goal"]) && String.match?(val, ~r/\*/) do
      {:does_not_match, val}
    else
      {:is_not, val}
    end
  end

  defp filter_value(key, val) do
    if String.contains?(key, ["page", "goal"]) && String.match?(val, ~r/\*/) do
      {:matches, val}
    else
      {:is, val}
    end
  end
end
