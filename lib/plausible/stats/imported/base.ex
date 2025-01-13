defmodule Plausible.Stats.Imported.Base do
  @moduledoc """
  A module for building the base of an imported stats query
  """

  import Ecto.Query

  alias Plausible.Imported
  alias Plausible.Stats.Query

  import Plausible.Stats.Filters, only: [dimensions_used_in_filters: 1]

  @property_to_table_mappings %{
    "visit:source" => "imported_sources",
    "visit:channel" => "imported_sources",
    "visit:referrer" => "imported_sources",
    "visit:utm_source" => "imported_sources",
    "visit:utm_medium" => "imported_sources",
    "visit:utm_campaign" => "imported_sources",
    "visit:utm_term" => "imported_sources",
    "visit:utm_content" => "imported_sources",
    "visit:entry_page" => "imported_entry_pages",
    "visit:exit_page" => "imported_exit_pages",
    "visit:country" => "imported_locations",
    "visit:region" => "imported_locations",
    "visit:city" => "imported_locations",
    "visit:country_name" => "imported_locations",
    "visit:region_name" => "imported_locations",
    "visit:city_name" => "imported_locations",
    "visit:device" => "imported_devices",
    "visit:browser" => "imported_browsers",
    "visit:browser_version" => "imported_browsers",
    "visit:os" => "imported_operating_systems",
    "visit:os_version" => "imported_operating_systems",
    "event:page" => "imported_pages",
    "event:name" => "imported_custom_events",

    # NOTE: these dimensions can be only filtered by
    "visit:screen" => "imported_devices",
    "event:hostname" => "imported_pages",

    # NOTE: These dimensions are only used in group by
    "time:month" => "imported_visitors",
    "time:week" => "imported_visitors",
    "time:day" => "imported_visitors",
    "time:hour" => "imported_visitors"
  }

  @queriable_time_dimensions ["time:month", "time:week", "time:day", "time:hour"]

  @imported_custom_props Imported.imported_custom_props()

  def property_to_table_mappings(), do: @property_to_table_mappings

  def query_imported(site, query) do
    [table] = decide_tables(query)

    query_imported(table, site, query)
  end

  def query_imported(table, site, query) do
    import_ids = site.complete_import_ids
    # Assumption: dates in imported table are in user-local timezone.
    %{first: date_from, last: date_to} = Query.date_range(query)

    from(i in table,
      where: i.site_id == ^site.id,
      where: i.import_id in ^import_ids,
      where: i.date >= ^date_from,
      where: i.date <= ^date_to,
      where: ^Plausible.Stats.Imported.SQL.WhereBuilder.build(query),
      select: %{}
    )
  end

  def decide_tables(query) do
    if custom_prop_query?(query) do
      do_decide_custom_prop_table(query)
    else
      do_decide_tables(query)
    end
  end

  defp custom_prop_query?(query) do
    dimensions_used_in_filters(query.filters)
    |> Enum.concat(query.dimensions)
    |> Enum.any?(&(&1 in @imported_custom_props))
  end

  defp do_decide_custom_prop_table(%{dimensions: [dimension]} = query)
       when dimension in @imported_custom_props do
    do_decide_custom_prop_table(query, dimension)
  end

  @queriable_custom_prop_dimensions ["event:goal", "event:name"] ++ @queriable_time_dimensions
  defp do_decide_custom_prop_table(%{dimensions: dimensions} = query) do
    if dimensions == [] or
         (length(dimensions) == 1 and hd(dimensions) in @queriable_custom_prop_dimensions) do
      custom_prop_filters =
        dimensions_used_in_filters(query.filters)
        |> Enum.filter(&(&1 in @imported_custom_props))
        |> Enum.uniq()

      case custom_prop_filters do
        [custom_prop_filter] ->
          do_decide_custom_prop_table(query, custom_prop_filter)

        _ ->
          []
      end
    else
      []
    end
  end

  defp do_decide_custom_prop_table(query, property) do
    has_required_name_filter? =
      query.filters
      |> Enum.flat_map(fn
        [:is, "event:name", names | _rest] -> names
        [:is, "event:goal", names | _rest] -> names
        _ -> []
      end)
      |> Enum.any?(&(&1 in special_goals_for(property)))

    has_unsupported_filters? =
      query.filters
      |> dimensions_used_in_filters()
      |> Enum.any?(&(&1 not in [property, "event:name", "event:goal"]))

    if has_required_name_filter? and not has_unsupported_filters? do
      ["imported_custom_events"]
    else
      []
    end
  end

  defp do_decide_tables(%Query{filters: [], dimensions: []}), do: ["imported_visitors"]

  defp do_decide_tables(%Query{filters: [], dimensions: ["event:goal"]}) do
    ["imported_pages", "imported_custom_events"]
  end

  defp do_decide_tables(%Query{dimensions: ["event:goal"]} = query) do
    filter_dimensions = dimensions_used_in_filters(query.filters)

    filter_goals = query.preloaded_goals

    any_event_goals? = Enum.any?(filter_goals, fn goal -> Plausible.Goal.type(goal) == :event end)

    any_pageview_goals? =
      Enum.any?(filter_goals, fn goal -> Plausible.Goal.type(goal) == :page end)

    any_event_name_filters? = "event:name" in filter_dimensions or any_event_goals?
    any_page_filters? = "event:page" in filter_dimensions or any_pageview_goals?

    any_other_filters? =
      Enum.any?(filter_dimensions, &(&1 not in ["event:page", "event:name", "event:goal"]))

    cond do
      any_other_filters? -> []
      any_event_name_filters? and not any_page_filters? -> ["imported_custom_events"]
      any_page_filters? and not any_event_name_filters? -> ["imported_pages"]
      true -> []
    end
  end

  defp do_decide_tables(query) do
    table_candidates =
      dimensions_used_in_filters(query.filters)
      |> Enum.concat(query.dimensions)
      |> Enum.reject(&(&1 in @queriable_time_dimensions or &1 == "event:goal"))
      |> Enum.flat_map(fn
        "visit:screen" -> ["visit:device"]
        dimension -> [dimension]
      end)
      |> Enum.map(&@property_to_table_mappings[&1])

    filter_goal_table_candidates =
      query.preloaded_goals
      |> Enum.map(&Plausible.Goal.type/1)
      |> Enum.map(fn
        :event -> "imported_custom_events"
        :page -> "imported_pages"
      end)

    case Enum.uniq(table_candidates ++ filter_goal_table_candidates) do
      [] -> ["imported_visitors"]
      [nil] -> []
      [candidate] -> [candidate]
      _ -> []
    end
  end

  def special_goals_for("event:props:url"), do: Imported.goals_with_url()
  def special_goals_for("event:props:path"), do: Imported.goals_with_path()
end
