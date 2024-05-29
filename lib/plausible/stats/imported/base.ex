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
    "event:props:url" => "imported_custom_events",
    "event:props:path" => "imported_custom_events",

    # NOTE: these properties can be only filtered by
    "visit:screen" => "imported_devices",
    "event:hostname" => "imported_pages"
  }

  @goals_with_url Imported.goals_with_url()
  @goals_with_path Imported.goals_with_path()

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
    query
    |> transform_filters()
    |> do_decide_table()
  end

  defp transform_filters(query) do
    new_filters =
      query.filters
      |> Enum.reject(fn
        [:is, "event:name", "pageview"] -> true
        _ -> false
      end)
      |> Enum.map(fn filter ->
        case filter do
          [:is, "event:goal", {:event, name}] ->
            [[:is, "event:name", name]]

          [:is, "event:goal", {:page, page}] ->
            [[:is, "event:page", page]]

          [:member, "event:goal", events] ->
            events
            |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
            |> Enum.map(fn
              {:event, names} -> [:member, "event:name", names]
              {:page, pages} -> [:member, "event:page", pages]
            end)

          filter ->
            [filter]
        end
      end)
      |> Enum.concat()

    struct!(query, filters: new_filters)
  end

  defp do_decide_table(%Query{filters: [], property: nil}), do: "imported_visitors"
  defp do_decide_table(%Query{filters: [], property: "event:props:url"}), do: nil
  defp do_decide_table(%Query{filters: [], property: "event:props:path"}), do: nil

  defp do_decide_table(%Query{filters: filters, property: "event:props:url"}) do
    case filters do
      [[:is, "event:name", name]] when name in @goals_with_url ->
        "imported_custom_events"

      _ ->
        nil
    end
  end

  defp do_decide_table(%Query{filters: filters, property: "event:props:path"}) do
    case filters do
      [[:is, "event:name", name]] when name in @goals_with_path ->
        "imported_custom_events"

      _ ->
        nil
    end
  end

  defp do_decide_table(%Query{filters: [], property: "event:goal"}) do
    "imported_custom_events"
  end

  defp do_decide_table(%Query{filters: [], property: property}) do
    @property_to_table_mappings[property]
  end

  defp do_decide_table(%Query{filters: filters, property: "event:goal"}) do
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

  defp do_decide_table(%Query{filters: filters, property: property}) do
    table_candidates =
      filters
      |> Enum.map(fn [_, prop | _] -> prop end)
      |> Enum.concat(if property, do: [property], else: [])
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
    Enum.reduce(filters, q, fn [_, filtered_prop | _] = filter, q ->
      db_field = Plausible.Stats.Filters.without_prefix(filtered_prop)
      mapped_db_field = Map.get(@db_field_mappings, db_field, db_field)
      condition = Filters.WhereBuilder.build_condition(mapped_db_field, filter)

      where(q, ^condition)
    end)
  end
end
