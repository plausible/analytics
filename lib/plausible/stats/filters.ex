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
    "country"
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
            new_val = Plausible.Stats.CountryName.to_alpha2(val)
            Map.put(new_filters, "visit:country", {:is, new_val})

          name == "page" ->
            if String.match?(val, ~r/\*/) do
              Map.put(new_filters, "event:page", {:matches, val})
            else
              Map.put(new_filters, "event:page", {:is, val})
            end

          name in (@visit_props ++ ["goal"]) ->
            Map.put(new_filters, "visit:" <> name, {:is, val})

          name in @event_props ->
            Map.put(new_filters, "event:" <> name, {:is, val})

          name == "props" ->
            Enum.reduce(val, new_filters, fn {prop_key, prop_val}, new_filters ->
              Map.put(new_filters, "event:props:" <> prop_key, {:is, prop_val})
            end)

          true ->
            Map.put(new_filters, name, {:is, val})
        end
      end)

    %Plausible.Stats.Query{query | filters: new_filters}
  end
end
