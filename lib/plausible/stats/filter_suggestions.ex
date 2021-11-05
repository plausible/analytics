defmodule Plausible.Stats.FilterSuggestions do
  use Plausible.Repo
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base
  alias Plausible.Stats.CountryName

  def filter_suggestions(site, query, "country", filter_search) do
    matches = Plausible.Stats.CountryName.search_alpha2(filter_search)

    q =
      from(
        e in query_sessions(site, query),
        group_by: e.country_code,
        order_by: [desc: fragment("count(*)")],
        select: e.country_code
      )

    ClickhouseRepo.all(q)
    |> Enum.filter(fn c -> Enum.find(matches, false, fn x -> x == c end) end)
    |> Enum.slice(0..24)
    |> Enum.map(fn c ->
      %{
        code: CountryName.to_alpha3(c),
        name: CountryName.from_iso3166(c)
      }
    end)
  end

  def filter_suggestions(site, query, "region", "") do
    from(
      e in query_sessions(site, query),
      group_by: e.subdivision1_code,
      order_by: [desc: fragment("count(*)")],
      select: e.subdivision1_code,
      where: e.subdivision1_code != "",
      limit: 24
    )
    |> ClickhouseRepo.all()
    |> Enum.map(fn c ->
      %{
        code: c,
        name: CountryName.from_iso3166_2(c)
      }
    end)
  end

  def filter_suggestions(site, query, "region", filter_search) do
    matches = Plausible.Stats.CountryName.search_iso3166_2(filter_search)

    q =
      from(
        e in query_sessions(site, query),
        group_by: e.subdivision1_code,
        order_by: [desc: fragment("count(*)")],
        select: e.subdivision1_code
      )

    ClickhouseRepo.all(q)
    |> Enum.filter(fn c -> Enum.find(matches, false, fn x -> x == c end) end)
    |> Enum.slice(0..24)
    |> Enum.map(fn c ->
      %{
        code: c,
        name: CountryName.from_iso3166_2(c)
      }
    end)
  end

  def filter_suggestions(site, query, "city", "") do
    from(
      e in query_sessions(site, query),
      group_by: e.city_geoname_id,
      order_by: [desc: fragment("count(*)")],
      select: e.city_geoname_id,
      where: e.city_geoname_id != 0,
      limit: 24
    )
    |> ClickhouseRepo.all()
    |> Enum.map(fn c ->
      %{
        code: Integer.to_string(c),
        name: CountryName.from_geoname_id(c, "N/A")
      }
    end)
  end

  def filter_suggestions(site, query, "city", filter_search) do
    matches = Plausible.Stats.CountryName.search_geoname(filter_search)

    q =
      from(
        e in query_sessions(site, query),
        group_by: e.city_geoname_id,
        order_by: [desc: fragment("count(*)")],
        select: e.city_geoname_id,
        where: e.city_geoname_id != 0
      )

    ClickhouseRepo.all(q)
    |> Enum.filter(fn c -> Enum.find(matches, false, fn x -> x == c end) end)
    |> Enum.slice(0..24)
    |> Enum.map(fn c ->
      %{
        code: Integer.to_string(c),
        name: CountryName.from_geoname_id(c, "N/A")
      }
    end)
  end

  def filter_suggestions(site, _query, "goal", filter_search) do
    Repo.all(from g in Plausible.Goal, where: g.domain == ^site.domain)
    |> Enum.map(fn x -> if x.event_name, do: x.event_name, else: "Visit #{x.page_path}" end)
    |> Enum.filter(fn goal ->
      String.contains?(
        String.downcase(goal),
        String.downcase(filter_search)
      )
    end)
  end

  def filter_suggestions(site, query, filter_name, filter_search) do
    filter_search = if filter_search == nil, do: "", else: filter_search

    filter_query =
      if Enum.member?(["entry_page", "page", "exit_page"], filter_name),
        do: "%#{String.replace(filter_search, "*", "")}%",
        else: "%#{filter_search}%"

    filter_name =
      case filter_name do
        "page" -> "pathname"
        "source" -> "referrer_source"
        "os" -> "operating_system"
        "os_version" -> "operating_system_version"
        "screen" -> "screen_size"
        _ -> filter_name
      end

    q =
      if(filter_name == "pathname",
        do: base_event_query(site, query),
        else: query_sessions(site, query)
      )
      |> from(
        group_by: ^String.to_atom(filter_name),
        order_by: [desc: fragment("count(*)")],
        limit: 25
      )

    q =
      case filter_name do
        "pathname" ->
          from(e in q,
            select: {e.pathname},
            where: fragment("? ilike ?", e.pathname, ^filter_query)
          )

        "entry_page" ->
          from(e in q,
            select: {e.entry_page},
            where: fragment("? ilike ?", e.entry_page, ^filter_query)
          )

        "exit_page" ->
          from(e in q,
            select: {e.exit_page},
            where: fragment("? ilike ?", e.exit_page, ^filter_query)
          )

        "referrer_source" ->
          from(e in q,
            select: {e.referrer_source},
            where: fragment("? ilike ?", e.referrer_source, ^filter_query)
          )

        "utm_medium" ->
          from(e in q,
            select: {e.utm_medium},
            where: fragment("? ilike ?", e.utm_medium, ^filter_query)
          )

        "utm_source" ->
          from(e in q,
            select: {e.utm_source},
            where: fragment("? ilike ?", e.utm_source, ^filter_query)
          )

        "utm_campaign" ->
          from(e in q,
            select: {e.utm_campaign},
            where: fragment("? ilike ?", e.utm_campaign, ^filter_query)
          )

        "referrer" ->
          from(e in q,
            select: {e.referrer},
            where: fragment("? ilike ?", e.referrer, ^filter_query)
          )

        "browser" ->
          from(e in q, select: {e.browser}, where: fragment("? ilike ?", e.browser, ^filter_query))

        "browser_version" ->
          from(e in q,
            select: {e.browser_version},
            where: fragment("? ilike ?", e.browser_version, ^filter_query)
          )

        "operating_system" ->
          from(e in q,
            select: {e.operating_system},
            where: fragment("? ilike ?", e.operating_system, ^filter_query)
          )

        "operating_system_version" ->
          from(e in q,
            select: {e.operating_system_version},
            where: fragment("? ilike ?", e.operating_system_version, ^filter_query)
          )

        "screen_size" ->
          from(e in q,
            select: {e.screen_size},
            where: fragment("? ilike ?", e.screen_size, ^filter_query)
          )
      end

    ClickhouseRepo.all(q)
    |> Enum.map(fn {suggestion} -> suggestion end)
    |> Enum.filter(fn suggestion -> suggestion != "" end)
  end
end
