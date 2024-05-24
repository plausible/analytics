defmodule Plausible.Stats.FilterSuggestions do
  use Plausible.Repo
  use Plausible.ClickhouseRepo
  use Plausible.Stats.Fragments
  import Plausible.Stats.Base
  import Ecto.Query
  alias Plausible.Stats.Query

  def filter_suggestions(site, query, "country", filter_search) do
    matches = Location.search_country(filter_search)

    q =
      from(
        e in query_sessions(site, query),
        group_by: e.country_code,
        order_by: [desc: fragment("count(*)")],
        select: e.country_code
      )
      |> Plausible.Stats.Imported.merged_imported_countries(site, query)

    ClickhouseRepo.all(q)
    |> Enum.map(fn c -> Enum.find(matches, fn x -> x.alpha_2 == c end) end)
    |> Enum.filter(& &1)
    |> Enum.slice(0..24)
    |> Enum.map(fn match ->
      %{
        value: match.alpha_2,
        label: match.name
      }
    end)
  end

  def filter_suggestions(site, query, "region", "") do
    from(
      e in query_sessions(site, query),
      group_by: e.subdivision1_code,
      order_by: [desc: fragment("count(*)")],
      select: e.subdivision1_code,
      where: e.subdivision1_code != ""
    )
    |> Plausible.Stats.Imported.merge_imported_regions(site, query)
    |> limit(24)
    |> ClickhouseRepo.all()
    |> Enum.map(fn c ->
      subdiv = Location.get_subdivision(c)

      %{
        value: c,
        label: subdiv.name
      }
    end)
  end

  def filter_suggestions(site, query, "region", filter_search) do
    matches = Location.search_subdivision(filter_search)

    q =
      from(
        e in query_sessions(site, query),
        group_by: e.subdivision1_code,
        order_by: [desc: fragment("count(*)")],
        select: e.subdivision1_code
      )
      |> Plausible.Stats.Imported.merge_imported_regions(site, query)

    ClickhouseRepo.all(q)
    |> Enum.map(fn c -> Enum.find(matches, fn x -> x.code == c end) end)
    |> Enum.filter(& &1)
    |> Enum.slice(0..24)
    |> Enum.map(fn subdiv ->
      %{
        value: subdiv.code,
        label: subdiv.name
      }
    end)
  end

  def filter_suggestions(site, query, "city", "") do
    from(
      e in query_sessions(site, query),
      group_by: e.city_geoname_id,
      order_by: [desc: fragment("count(*)")],
      select: e.city_geoname_id,
      where: e.city_geoname_id != 0
    )
    |> Plausible.Stats.Imported.merge_imported_cities(site, query)
    |> limit(24)
    |> ClickhouseRepo.all()
    |> Enum.map(fn c ->
      city = Location.get_city(c)

      %{
        value: Integer.to_string(c),
        label: (city && city.name) || "N/A"
      }
    end)
  end

  def filter_suggestions(site, query, "city", filter_search) do
    filter_search = String.downcase(filter_search)

    q =
      from(
        e in query_sessions(site, query),
        group_by: e.city_geoname_id,
        order_by: [desc: fragment("count(*)")],
        select: e.city_geoname_id,
        where: e.city_geoname_id != 0
      )
      |> Plausible.Stats.Imported.merge_imported_cities(site, query)
      |> limit(5000)

    ClickhouseRepo.all(q)
    |> Enum.map(fn c -> Location.get_city(c) end)
    |> Enum.filter(fn city ->
      city && String.contains?(String.downcase(city.name), filter_search)
    end)
    |> Enum.slice(0..24)
    |> Enum.map(fn c ->
      %{
        value: Integer.to_string(c.id),
        label: c.name
      }
    end)
  end

  def filter_suggestions(site, _query, "goal", filter_search) do
    site
    |> Plausible.Goals.for_site()
    |> Enum.map(fn x -> if x.event_name, do: x.event_name, else: "Visit #{x.page_path}" end)
    |> Enum.filter(fn goal ->
      String.contains?(
        String.downcase(goal),
        String.downcase(filter_search)
      )
    end)
    |> wrap_suggestions()
  end

  def filter_suggestions(site, query, "prop_key", filter_search) do
    filter_query = if filter_search == nil, do: "%", else: "%#{filter_search}%"

    from(e in base_event_query(site, query),
      array_join: meta in "meta",
      as: :meta,
      select: meta.key,
      where: fragment("? ilike ?", meta.key, ^filter_query),
      group_by: meta.key,
      order_by: [desc: fragment("count(*)")],
      limit: 25
    )
    |> Plausible.Stats.CustomProps.maybe_allowed_props_only(site)
    |> ClickhouseRepo.all()
    |> wrap_suggestions()
  end

  def filter_suggestions(site, query, "prop_value", filter_search) do
    filter_query = if filter_search == nil, do: "%", else: "%#{filter_search}%"

    [_op, "event:props:" <> key | _rest] = Query.get_filter_by_prefix(query, "event:props")

    none_q =
      from(e in base_event_query(site, Query.remove_filters(query, ["event:props"])),
        select: "(none)",
        where: not has_key(e, :meta, ^key),
        limit: 1
      )

    search_q =
      from(e in base_event_query(site, query),
        select: get_by_key(e, :meta, ^key),
        where:
          has_key(e, :meta, ^key) and
            fragment(
              "? ilike ?",
              get_by_key(e, :meta, ^key),
              ^filter_query
            ),
        group_by: get_by_key(e, :meta, ^key),
        order_by: [desc: fragment("count(*)")],
        limit: 25
      )

    ClickhouseRepo.all(none_q)
    |> Kernel.++(ClickhouseRepo.all(search_q))
    |> wrap_suggestions()
  end

  def filter_suggestions(site, query, filter_name, filter_search) do
    filter_search = if filter_search == nil, do: "", else: filter_search

    filter_query =
      if Enum.member?(["entry_page", "page", "exit_page"], filter_name),
        do: "%#{String.replace(filter_search, "*", "")}%",
        else: "%#{filter_search}%"

    filter_name =
      case filter_name do
        "page" -> :pathname
        "entry_page" -> :entry_page
        "source" -> :referrer_source
        "os" -> :operating_system
        "os_version" -> :operating_system_version
        "screen" -> :screen_size
        "exit_page" -> :exit_page
        "utm_source" -> :utm_source
        "utm_medium" -> :utm_medium
        "utm_campaign" -> :utm_campaign
        "utm_content" -> :utm_content
        "utm_term" -> :utm_term
        "referrer" -> :referrer
        "browser" -> :browser
        "browser_version" -> :browser_version
        "operating_system" -> :operating_system
        "operating_system_version" -> :operating_system_version
        "screen_size" -> :screen_size
        "hostname" -> :hostname
      end

    base_q =
      if filter_name in [:pathname, :hostname] do
        base_event_query(site, query)
      else
        query_sessions(site, query)
      end

    from(e in base_q,
      where: fragment("? ilike ?", field(e, ^filter_name), ^filter_query),
      select: field(e, ^filter_name),
      group_by: ^filter_name,
      order_by: [desc: fragment("count(*)")]
    )
    |> apply_additional_filters(filter_name, site)
    |> Plausible.Stats.Imported.merge_imported_filter_suggestions(
      site,
      query,
      filter_name,
      filter_query
    )
    |> limit(25)
    |> ClickhouseRepo.all()
    |> Enum.filter(fn suggestion -> suggestion != "" end)
    |> wrap_suggestions()
  end

  defp apply_additional_filters(q, :hostname, site) do
    case Plausible.Shields.allowed_hostname_patterns(site.domain) do
      :all ->
        q

      limited_to when is_list(limited_to) ->
        from(e in q,
          where: fragment("multiMatchAny(?, ?)", e.hostname, ^limited_to)
        )
    end
  end

  defp apply_additional_filters(q, _, _), do: q

  defp wrap_suggestions(list) do
    Enum.map(list, fn val -> %{value: val, label: val} end)
  end
end
