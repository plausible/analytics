defmodule Plausible.Stats.Imported.Base do
  @moduledoc """
  A module for building the base of an imported stats query
  """

  import Ecto.Query

  alias Plausible.Imported
  alias Plausible.Stats.Filters
  alias Plausible.Stats.Query

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

    # NOTE: these properties can be only filtered by
    "visit:screen" => "imported_devices",
    "event:hostname" => "imported_pages"
  }

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
    query
    |> transform_filters()
    |> decide_table()
    |> query_imported(site, query)
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

  def decide_table(query) do
    query = transform_filters(query)

    if custom_prop_query?(query) do
      do_decide_custom_prop_table(query)
    else
      do_decide_table(query)
    end
  end

  defp transform_filters(query) do
    new_filters =
      query.filters
      |> Enum.reject(fn
        [:is, "event:name", ["pageview"]] -> true
        _ -> false
      end)
      |> Enum.flat_map(fn filter ->
        case filter do
          [op, "event:goal", events] ->
            events
            |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
            |> Enum.map(fn
              {:event, names} -> [op, "event:name", names]
              {:page, pages} -> [op, "event:page", pages]
            end)

          filter ->
            [filter]
        end
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

  defp do_decide_custom_prop_table(%{dimensions: dimensions} = query) do
    if dimensions == [] or
         (length(dimensions) == 1 and hd(dimensions) in ["event:goal", "event:name"]) do
      custom_prop_filters =
        query.filters
        |> Enum.map(&Enum.at(&1, 1))
        |> Enum.filter(&(&1 in @imported_custom_props))
        |> Enum.uniq()

      case custom_prop_filters do
        [custom_prop_filter] ->
          do_decide_custom_prop_table(query, custom_prop_filter)

        _ ->
          nil
      end
    else
      nil
    end
  end

  defp do_decide_custom_prop_table(_query), do: nil

  defp do_decide_custom_prop_table(query, property) do
    has_required_name_filter? =
      query.filters
      |> Enum.flat_map(fn
        [:is, "event:name", names] -> names
        _ -> []
      end)
      |> Enum.any?(&(&1 in special_goals_for(property)))

    has_unsupported_filters? =
      Enum.any?(query.filters, fn [_, filter_key | _] ->
        filter_key not in [property, "event:name"]
      end)

    if has_required_name_filter? and not has_unsupported_filters? do
      "imported_custom_events"
    else
      nil
    end
  end

  defp do_decide_table(%Query{filters: [], dimensions: []}), do: "imported_visitors"

  defp do_decide_table(%Query{filters: [], dimensions: ["event:goal"]}) do
    "imported_custom_events"
  end

  defp do_decide_table(%Query{filters: [], dimensions: [dimension]}) do
    @property_to_table_mappings[dimension]
  end

  defp do_decide_table(%Query{filters: filters, dimensions: ["event:goal"]}) do
    filter_props = Enum.map(filters, &Enum.at(&1, 1))

    any_event_name_filters? = "event:name" in filter_props
    any_page_filters? = "event:page" in filter_props
    any_other_filters? = Enum.any?(filter_props, &(&1 not in ["event:page", "event:name"]))

    cond do
      any_other_filters? -> nil
      any_event_name_filters? and not any_page_filters? -> "imported_custom_events"
      any_page_filters? and not any_event_name_filters? -> "imported_pages"
      true -> nil
    end
  end

  defp do_decide_table(%Query{filters: filters, dimensions: dimensions}) do
    table_candidates =
      filters
      |> Enum.map(fn [_, filter_key | _] -> filter_key end)
      |> Enum.concat(dimensions)
      |> Enum.map(fn
        "visit:screen" -> "visit:device"
        prop -> prop
      end)
      |> Enum.map(&@property_to_table_mappings[&1])

    case Enum.uniq(table_candidates) do
      [candidate] -> candidate
      _ -> nil
    end
  end

  defp apply_filter(q, %Query{filters: filters}) do
    Enum.reduce(filters, q, fn [_, filter_key | _] = filter, q ->
      db_field = Plausible.Stats.Filters.without_prefix(filter_key)
      mapped_db_field = Map.get(@db_field_mappings, db_field, db_field)
      condition = Filters.WhereBuilder.build_condition(mapped_db_field, filter)

      where(q, ^condition)
    end)
  end

  def special_goals_for("event:props:url"), do: Imported.goals_with_url()
  def special_goals_for("event:props:path"), do: Imported.goals_with_path()
end
