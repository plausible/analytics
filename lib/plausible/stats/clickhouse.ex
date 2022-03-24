defmodule Plausible.Stats.Clickhouse do
  use Plausible.Repo
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.Query
  use Plausible.Stats.Fragments
  @no_ref "Direct / None"

  def pageview_start_date_local(site) do
    datetime =
      ClickhouseRepo.one(
        from e in "events",
          select: fragment("min(?)", e.timestamp),
          where: e.domain == ^site.domain
      )

    case datetime do
      # no stats for this domain yet
      ~N[1970-01-01 00:00:00] ->
        Timex.today(site.timezone)

      _ ->
        Timex.Timezone.convert(datetime, "UTC")
        |> Timex.Timezone.convert(site.timezone)
        |> DateTime.to_date()
    end
  end

  def imported_pageview_count(site) do
    Plausible.ClickhouseRepo.one(
      from i in "imported_visitors",
        where: i.site_id == ^site.id,
        select: sum(i.pageviews)
    )
  end

  def usage_breakdown(domains) do
    range =
      Date.range(
        Timex.shift(Timex.today(), days: -30),
        Timex.today()
      )

    usage_breakdown(domains, range)
  end

  def usage_breakdown(domains, date_range) do
    Enum.chunk_every(domains, 300)
    |> Enum.reduce({0, 0}, fn domains, {pageviews_total, custom_events_total} ->
      {chunk_pageviews, chunk_custom_events} =
        ClickhouseRepo.one(
          from e in "events",
            where: e.domain in ^domains,
            where: fragment("toDate(?)", e.timestamp) >= ^date_range.first,
            where: fragment("toDate(?)", e.timestamp) <= ^date_range.last,
            select: {
              fragment("countIf(? = 'pageview')", e.name),
              fragment("countIf(? != 'pageview')", e.name)
            }
        )

      {pageviews_total + chunk_pageviews, custom_events_total + chunk_custom_events}
    end)
  end

  def top_sources(site, query, limit, page, show_noref \\ false, include_details) do
    offset = (page - 1) * limit

    referrers =
      from(s in base_session_query(site, query),
        group_by: s.referrer_source,
        order_by: [desc: uniq(s.user_id), asc: fragment("min(start)")],
        limit: ^limit,
        offset: ^offset
      )
      |> filter_converted_sessions(site, query)

    referrers =
      if show_noref do
        referrers
      else
        from(s in referrers, where: s.referrer_source != "")
      end

    referrers = apply_page_as_entry_page(referrers, site, query)

    referrers =
      if include_details do
        from(
          s in referrers,
          select: %{
            name:
              fragment(
                "if(empty(?), ?, ?) as name",
                s.referrer_source,
                @no_ref,
                s.referrer_source
              ),
            url: fragment("any(?)", s.referrer),
            count: uniq(s.user_id),
            bounce_rate: bounce_rate(),
            visit_duration: visit_duration()
          }
        )
      else
        from(
          s in referrers,
          select: %{
            name:
              fragment(
                "if(empty(?), ?, ?) as name",
                s.referrer_source,
                @no_ref,
                s.referrer_source
              ),
            url: fragment("any(?)", s.referrer),
            count: uniq(s.user_id)
          }
        )
      end

    ClickhouseRepo.all(referrers)
    |> Enum.map(fn ref ->
      Map.update(ref, :url, nil, fn url -> url && URI.parse("http://" <> url).host end)
    end)
  end

  defp filter_converted_sessions(db_query, site, query) do
    goal = query.filters["goal"]
    page = query.filters[:page]

    if is_binary(goal) || is_binary(page) do
      converted_sessions =
        from(e in base_query(site, query),
          select: %{session_id: fragment("DISTINCT ?", e.session_id)}
        )

      from(s in db_query,
        join: cs in subquery(converted_sessions),
        on: s.session_id == cs.session_id
      )
    else
      db_query
    end
  end

  defp apply_page_as_entry_page(db_query, _site, query) do
    include_path_filter_entry(db_query, query.filters[:page])
  end

  def current_visitors(site, query) do
    Plausible.ClickhouseRepo.one(
      from e in base_query(site, query),
        select: uniq(e.user_id)
    )
  end

  def has_pageviews?([]), do: false

  def has_pageviews?(domains) when is_list(domains) do
    ClickhouseRepo.exists?(
      from e in "events",
        select: e.timestamp,
        where: fragment("? IN tuple(?)", e.domain, ^domains)
    )
  end

  def has_pageviews?(site) do
    ClickhouseRepo.exists?(
      from e in "events", where: e.domain == ^site.domain and e.name == "pageview"
    )
  end

  def last_24h_visitors([]), do: %{}

  def last_24h_visitors(sites) do
    domains = Enum.map(sites, & &1.domain)

    ClickhouseRepo.all(
      from e in "events",
        group_by: e.domain,
        where: fragment("? IN tuple(?)", e.domain, ^domains),
        where: e.timestamp > fragment("now() - INTERVAL 24 HOUR"),
        select: {e.domain, fragment("uniq(user_id)")}
    )
    |> Enum.into(%{})
  end

  defp base_session_query(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    q =
      from(s in "sessions",
        hints: ["SAMPLE 10000000"],
        where: s.domain == ^site.domain,
        where: s.timestamp >= ^first_datetime and s.start < ^last_datetime
      )

    q =
      if query.filters["source"] do
        source = query.filters["source"]
        source = if source == @no_ref, do: "", else: source
        from(s in q, where: s.referrer_source == ^source)
      else
        q
      end

    q =
      if query.filters["screen"] do
        size = query.filters["screen"]
        from(s in q, where: s.screen_size == ^size)
      else
        q
      end

    q =
      if query.filters["browser"] do
        browser = query.filters["browser"]
        from(s in q, where: s.browser == ^browser)
      else
        q
      end

    q =
      if query.filters["browser_version"] do
        version = query.filters["browser_version"]
        from(s in q, where: s.browser_version == ^version)
      else
        q
      end

    q =
      if query.filters["os"] do
        os = query.filters["os"]
        from(s in q, where: s.operating_system == ^os)
      else
        q
      end

    q =
      if query.filters["os_version"] do
        version = query.filters["os_version"]
        from(s in q, where: s.operating_system_version == ^version)
      else
        q
      end

    q =
      if query.filters["country"] do
        country = query.filters["country"]
        from(s in q, where: s.country_code == ^country)
      else
        q
      end

    q =
      if query.filters["utm_medium"] do
        utm_medium = query.filters["utm_medium"]
        from(s in q, where: s.utm_medium == ^utm_medium)
      else
        q
      end

    q =
      if query.filters["utm_source"] do
        utm_source = query.filters["utm_source"]
        from(s in q, where: s.utm_source == ^utm_source)
      else
        q
      end

    q =
      if query.filters["utm_campaign"] do
        utm_campaign = query.filters["utm_campaign"]
        from(s in q, where: s.utm_campaign == ^utm_campaign)
      else
        q
      end

    q =
      if query.filters["utm_content"] do
        utm_content = query.filters["utm_content"]
        from(s in q, where: s.utm_content == ^utm_content)
      else
        q
      end

    q =
      if query.filters["utm_term"] do
        utm_term = query.filters["utm_term"]
        from(s in q, where: s.utm_term == ^utm_term)
      else
        q
      end

    q = include_path_filter_entry(q, query.filters["entry_page"])

    q = include_path_filter_exit(q, query.filters["exit_page"])

    if query.filters["referrer"] do
      ref = query.filters["referrer"]
      from(s in q, where: s.referrer == ^ref)
    else
      q
    end
  end

  defp base_query_bare(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    q =
      from(e in "events",
        hints: ["SAMPLE 10000000"],
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    q =
      if query.filters["screen"] do
        size = query.filters["screen"]
        from(e in q, where: e.screen_size == ^size)
      else
        q
      end

    q =
      if query.filters["browser"] do
        browser = query.filters["browser"]
        from(s in q, where: s.browser == ^browser)
      else
        q
      end

    q =
      if query.filters["browser_version"] do
        version = query.filters["browser_version"]
        from(s in q, where: s.browser_version == ^version)
      else
        q
      end

    q =
      if query.filters["os"] do
        os = query.filters["os"]
        from(s in q, where: s.operating_system == ^os)
      else
        q
      end

    q =
      if query.filters["os_version"] do
        version = query.filters["os_version"]
        from(s in q, where: s.operating_system_version == ^version)
      else
        q
      end

    q =
      if query.filters["country"] do
        country = query.filters["country"]
        from(s in q, where: s.country_code == ^country)
      else
        q
      end

    q =
      if query.filters["utm_medium"] do
        utm_medium = query.filters["utm_medium"]
        from(e in q, where: e.utm_medium == ^utm_medium)
      else
        q
      end

    q =
      if query.filters["utm_source"] do
        utm_source = query.filters["utm_source"]
        from(e in q, where: e.utm_source == ^utm_source)
      else
        q
      end

    q =
      if query.filters["utm_campaign"] do
        utm_campaign = query.filters["utm_campaign"]
        from(e in q, where: e.utm_campaign == ^utm_campaign)
      else
        q
      end

    q =
      if query.filters["utm_content"] do
        utm_content = query.filters["utm_content"]
        from(e in q, where: e.utm_content == ^utm_content)
      else
        q
      end

    q =
      if query.filters["utm_term"] do
        utm_term = query.filters["utm_term"]
        from(e in q, where: e.utm_term == ^utm_term)
      else
        q
      end

    q =
      if query.filters["referrer"] do
        ref = query.filters["referrer"]
        from(e in q, where: e.referrer == ^ref)
      else
        q
      end

    q = include_path_filter(q, query.filters[:page])

    if query.filters["props"] do
      [{key, val}] = query.filters["props"] |> Enum.into([])

      if val == "(none)" do
        from(
          e in q,
          where: fragment("not has(meta.key, ?)", ^key)
        )
      else
        from(
          e in q,
          inner_lateral_join: meta in fragment("meta as m"),
          where: meta.key == ^key and meta.value == ^val
        )
      end
    else
      q
    end
  end

  defp base_query(site, query) do
    base_query_bare(site, query) |> include_goal_conversions(query)
  end

  defp utc_boundaries(%Query{period: "30m"}, _timezone) do
    last_datetime = NaiveDateTime.utc_now()

    first_datetime = last_datetime |> Timex.shift(minutes: -30)
    {first_datetime, last_datetime}
  end

  defp utc_boundaries(%Query{period: "realtime"}, _timezone) do
    last_datetime = NaiveDateTime.utc_now()

    first_datetime = last_datetime |> Timex.shift(minutes: -5)
    {first_datetime, last_datetime}
  end

  defp utc_boundaries(%Query{date_range: date_range}, timezone) do
    {:ok, first} = NaiveDateTime.new(date_range.first, ~T[00:00:00])

    first_datetime =
      Timex.to_datetime(first, timezone)
      |> Timex.Timezone.convert("UTC")

    {:ok, last} = NaiveDateTime.new(date_range.last |> Timex.shift(days: 1), ~T[00:00:00])

    last_datetime =
      Timex.to_datetime(last, timezone)
      |> Timex.Timezone.convert("UTC")

    {first_datetime, last_datetime}
  end

  defp event_name_for_goal(query) do
    case query.filters["goal"] do
      "Visit " <> page ->
        {"pageview", page}

      goal when is_binary(goal) ->
        {goal, nil}

      _ ->
        {nil, nil}
    end
  end

  defp include_goal_conversions(db_query, query) do
    {goal_event, path} = event_name_for_goal(query)

    q =
      if goal_event do
        from(e in db_query, where: e.name == ^goal_event)
      else
        from(e in db_query, where: e.name == "pageview")
      end

    if path do
      {contains_regex, path_regex} = convert_path_regex(path)

      if contains_regex do
        from(e in q, where: fragment("match(?, ?)", e.pathname, ^path_regex))
      else
        from(e in q, where: e.pathname == ^path)
      end
    else
      q
    end
  end

  defp check_negated_filter(filter) do
    negated = String.at(filter, 0) == "!"
    updated_filter = if negated, do: String.slice(filter, 1..-1), else: filter

    {negated, updated_filter}
  end

  defp convert_path_regex(path) do
    contains_regex = String.match?(path, ~r/\*/)

    regex =
      "^#{path}\/?$"
      |> String.replace(~r/\*\*/, ".*")
      |> String.replace(~r/(?<!\.)\*/, "[^/]*")

    {contains_regex, regex}
  end

  defp include_path_filter(db_query, path) do
    if path do
      {negated, path} = check_negated_filter(path)
      {contains_regex, path_regex} = convert_path_regex(path)

      if contains_regex do
        if negated do
          from(e in db_query, where: fragment("not(match(?, ?))", e.pathname, ^path_regex))
        else
          from(e in db_query, where: fragment("match(?, ?)", e.pathname, ^path_regex))
        end
      else
        if negated do
          from(e in db_query, where: e.pathname != ^path)
        else
          from(e in db_query, where: e.pathname == ^path)
        end
      end
    else
      db_query
    end
  end

  defp include_path_filter_entry(db_query, path) do
    if path do
      {negated, path} = check_negated_filter(path)
      {contains_regex, path_regex} = convert_path_regex(path)

      if contains_regex do
        if negated do
          from(e in db_query, where: fragment("not(match(?, ?))", e.entry_page, ^path_regex))
        else
          from(e in db_query, where: fragment("match(?, ?)", e.entry_page, ^path_regex))
        end
      else
        if negated do
          from(e in db_query, where: e.entry_page != ^path)
        else
          from(e in db_query, where: e.entry_page == ^path)
        end
      end
    else
      db_query
    end
  end

  defp include_path_filter_exit(db_query, path) do
    if path do
      {negated, path} = check_negated_filter(path)
      {contains_regex, path_regex} = convert_path_regex(path)

      if contains_regex do
        if negated do
          from(e in db_query, where: fragment("not(match(?, ?))", e.exit_page, ^path_regex))
        else
          from(e in db_query, where: fragment("match(?, ?)", e.exit_page, ^path_regex))
        end
      else
        if negated do
          from(e in db_query, where: e.exit_page != ^path)
        else
          from(e in db_query, where: e.exit_page == ^path)
        end
      end
    else
      db_query
    end
  end
end
