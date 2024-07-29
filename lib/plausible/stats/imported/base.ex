defmodule Plausible.Stats.Imported.Base do
  @moduledoc """
  A module for building the base of an imported stats query
  """

  import Ecto.Query

  alias Plausible.Imported
  alias Plausible.Stats.{Filters, Query, SQL}

  @property_to_table_mappings %{
    "visit:source" => "imported_sources",
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

  @db_field_mappings %{
    referrer_source: :source,
    screen_size: :device,
    screen: :device,
    os: :operating_system,
    os_version: :operating_system_version,
    country_code: :country,
    subdivision1_code: :region,
    city_geoname_id: :city,
    entry_page_hostname: :hostname,
    pathname: :page,
    url: :link_url
  }

  def property_to_table_mappings(), do: @property_to_table_mappings

  def query_imported(site, query) do
    [table] =
      query
      |> transform_filters()
      |> decide_tables()

    query_imported(table, site, query)
  end

  def query_imported(table, site, query) do
    query = transform_filters(query)
    import_ids = site.complete_import_ids
    %{first: date_from, last: date_to} = query.date_range

    from(i in table,
      where: i.site_id == ^site.id,
      where: i.import_id in ^import_ids,
      where: i.date >= ^date_from,
      where: i.date <= ^date_to,
      select: %{}
    )
    |> apply_filter(query)
  end

  def decide_tables(query) do
    query = transform_filters(query)

    if custom_prop_query?(query) do
      do_decide_custom_prop_table(query)
    else
      do_decide_tables(query)
    end
  end

  defp transform_filters(query) do
    new_filters =
      query.filters
      |> Enum.reject(fn
        [:is, "event:name", ["pageview"]] -> true
        _ -> false
      end)

    struct!(query, filters: new_filters)
  end

  defp custom_prop_query?(query) do
    query.filters
    |> Enum.map(&Enum.at(&1, 1))
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
        query.filters
        |> Enum.map(&Enum.at(&1, 1))
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
        [:is, "event:name", names] -> names
        [:is, "event:goal", names] -> names
        _ -> []
      end)
      |> Enum.any?(&(&1 in special_goals_for(property)))

    has_unsupported_filters? =
      Enum.any?(query.filters, fn [_, filter_key | _] ->
        filter_key not in [property, "event:name", "event:goal"]
      end)

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

  defp do_decide_tables(%Query{filters: filters, dimensions: ["event:goal"]} = query) do
    filter_props = Enum.map(filters, &Enum.at(&1, 1))

    filter_goals = get_filter_goals(query)

    any_event_goals? = Enum.any?(filter_goals, fn goal -> Plausible.Goal.type(goal) == :event end)

    any_pageview_goals? =
      Enum.any?(filter_goals, fn goal -> Plausible.Goal.type(goal) == :page end)

    any_event_name_filters? = "event:name" in filter_props or any_event_goals?
    any_page_filters? = "event:page" in filter_props or any_pageview_goals?

    any_other_filters? =
      Enum.any?(filter_props, &(&1 not in ["event:page", "event:name", "event:goal"]))

    cond do
      any_other_filters? -> []
      any_event_name_filters? and not any_page_filters? -> ["imported_custom_events"]
      any_page_filters? and not any_event_name_filters? -> ["imported_pages"]
      true -> []
    end
  end

  defp do_decide_tables(%Query{filters: filters, dimensions: dimensions} = query) do
    table_candidates =
      filters
      |> Enum.map(fn [_, filter_key | _] -> filter_key end)
      |> Enum.concat(dimensions)
      |> Enum.reject(&(&1 in @queriable_time_dimensions or &1 == "event:goal"))
      |> Enum.flat_map(fn
        "visit:screen" -> ["visit:device"]
        dimension -> [dimension]
      end)
      |> Enum.map(&@property_to_table_mappings[&1])

    filter_goal_table_candidates =
      query
      |> get_filter_goals()
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

  defp get_filter_goals(%Query{filters: filters} = query) do
    filters
    |> Enum.filter(fn [_, key, _] -> key == "event:goal" end)
    |> Enum.flat_map(fn [operation, _, clauses] ->
      Enum.flat_map(clauses, fn clause ->
        query.preloaded_goals
        |> Plausible.Goals.Filters.filter_preloaded(operation, clause)
      end)
    end)
  end

  defp apply_filter(q, %Query{filters: filters} = query) do
    Enum.reduce(filters, q, fn [_, filter_key, _] = filter, q ->
      db_field = Filters.without_prefix(filter_key)

      if db_field == :goal do
        condition = Plausible.Goals.Filters.add_filter(query, filter, imported?: true)
        where(q, ^condition)
      else
        mapped_db_field = Map.get(@db_field_mappings, db_field, db_field)
        condition = SQL.WhereBuilder.build_condition(mapped_db_field, filter)

        where(q, ^condition)
      end
    end)
  end

  def special_goals_for("event:props:url"), do: Imported.goals_with_url()
  def special_goals_for("event:props:path"), do: Imported.goals_with_path()
end
