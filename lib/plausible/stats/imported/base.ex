defmodule Plausible.Stats.Imported.Base do
  @moduledoc """
  A module for building the base of an imported stats query
  """
  alias Plausible.Stats.{Query, Imported, Filters}

  import Ecto.Query

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

  def query_imported(site, query) do
    query
    |> Imported.transform_filters()
    |> decide_table()
    |> query_imported(site, query)
  end

  def query_imported(table, site, query) do
    query = Imported.transform_filters(query)
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

  def decide_table(%Query{filters: [], property: nil}), do: "imported_visitors"
  def decide_table(%Query{filters: [], property: "event:props:url"}), do: nil
  def decide_table(%Query{filters: [], property: "event:props:path"}), do: nil

  def decide_table(%Query{filters: filters, property: "event:props:url"}) do
    case filters do
      [[:is, "event:name", name]] when name in @goals_with_url ->
        "imported_custom_events"

      _ ->
        nil
    end
  end

  def decide_table(%Query{filters: filters, property: "event:props:path"}) do
    case filters do
      [[:is, "event:name", name]] when name in @goals_with_path ->
        "imported_custom_events"

      _ ->
        nil
    end
  end

  def decide_table(%Query{filters: [], property: "event:goal"}) do
    "imported_custom_events"
  end

  def decide_table(%Query{filters: [], property: property}) do
    Imported.property_to_table_mappings()[property]
  end

  def decide_table(%Query{filters: filters, property: "event:goal"}) do
    any_event_name_filters? =
      filters
      |> Enum.filter(fn filter -> Enum.at(filter, 1) in ["event:name"] end)
      |> Enum.any?()

    any_page_filters? =
      filters
      |> Enum.filter(fn filter -> Enum.at(filter, 1) in ["event:page"] end)
      |> Enum.any?()

    any_other_filters? =
      filters
      |> Enum.filter(fn filter -> Enum.at(filter, 1) not in ["event:page", "event:name"] end)
      |> Enum.any?()

    cond do
      any_other_filters? -> nil
      any_event_name_filters? && !any_page_filters? -> "imported_custom_events"
      any_page_filters? && !any_event_name_filters? -> "imported_pages"
      true -> nil
    end
  end

  def decide_table(%Query{filters: filters, property: property}) do
    table_candidates =
      filters
      |> Enum.map(fn [_, prop | _] -> prop end)
      |> Enum.concat(if property, do: [property], else: [])
      |> Enum.map(fn
        "visit:screen" -> "visit:device"
        prop -> prop
      end)
      |> Enum.map(&Imported.property_to_table_mappings()[&1])

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
