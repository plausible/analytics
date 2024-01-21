defmodule Plausible.Stats.Clickhouse do
  use Plausible
  use Plausible.Repo
  use Plausible.ClickhouseRepo
  use Plausible.Stats.Fragments

  import Ecto.Query, only: [from: 2]

  alias Plausible.Stats.Query
  alias Plausible.Timezones

  @no_ref "Direct / None"

  @spec pageview_start_date_local(Plausible.Site.t()) :: Date.t() | nil
  def pageview_start_date_local(site) do
    datetime =
      ClickhouseRepo.one(
        from(e in "events_v2",
          select: fragment("min(?)", e.timestamp),
          where: e.site_id == ^site.id,
          where: e.timestamp >= ^site.native_stats_start_at
        )
      )

    case datetime do
      # no stats for this domain yet
      ~N[1970-01-01 00:00:00] ->
        nil

      _ ->
        Timezones.to_date_in_timezone(datetime, site.timezone)
    end
  end

  def imported_pageview_count(site) do
    Plausible.ClickhouseRepo.one(
      from(i in "imported_visitors",
        where: i.site_id == ^site.id,
        select: sum(i.pageviews)
      )
    )
  end

  def usage_breakdown([d | _] = domains, date_range) when is_binary(d) do
    Enum.chunk_every(domains, 300)
    |> Enum.reduce({0, 0}, fn domains, {pageviews_total, custom_events_total} ->
      {chunk_pageviews, chunk_custom_events} =
        ClickhouseRepo.one(
          from(e in "events",
            where: e.domain in ^domains,
            where: fragment("toDate(?)", e.timestamp) >= ^date_range.first,
            where: fragment("toDate(?)", e.timestamp) <= ^date_range.last,
            select: {
              fragment("countIf(? = 'pageview')", e.name),
              fragment("countIf(? != 'pageview')", e.name)
            }
          )
        )

      {pageviews_total + chunk_pageviews, custom_events_total + chunk_custom_events}
    end)
  end

  def usage_breakdown([sid | _] = site_ids, date_range) when is_integer(sid) do
    Enum.chunk_every(site_ids, 300)
    |> Enum.reduce({0, 0}, fn site_ids, {pageviews_total, custom_events_total} ->
      {chunk_pageviews, chunk_custom_events} =
        ClickhouseRepo.one(
          from(e in "events_v2",
            where: e.site_id in ^site_ids,
            where: fragment("toDate(?)", e.timestamp) >= ^date_range.first,
            where: fragment("toDate(?)", e.timestamp) <= ^date_range.last,
            select: {
              fragment("countIf(? = 'pageview')", e.name),
              fragment("countIf(? != 'pageview')", e.name)
            }
          )
        )

      {pageviews_total + chunk_pageviews, custom_events_total + chunk_custom_events}
    end)
  end

  def usage_breakdown([], _date_range), do: {0, 0}

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
      from(e in base_query(site, query),
        select: uniq(e.user_id)
      )
    )
  end

  def has_pageviews?(site) do
    ClickhouseRepo.exists?(
      from(e in "events_v2",
        where:
          e.site_id == ^site.id and
            e.name == "pageview" and
            e.timestamp >=
              ^site.native_stats_start_at
      )
    )
  end

  @spec empty_24h_visitors_hourly_intervals([Plausible.Site.t()], NaiveDateTime.t()) :: map()
  def empty_24h_visitors_hourly_intervals(sites, now \\ NaiveDateTime.utc_now()) do
    sites
    |> Enum.map(fn site ->
      {site.domain,
       %{
         intervals: empty_24h_intervals(now),
         visitors: 0,
         change: 0
       }}
    end)
    |> Map.new()
  end

  @spec last_24h_visitors_hourly_intervals([Plausible.Site.t()], NaiveDateTime.t()) :: map()
  def last_24h_visitors_hourly_intervals(sites, now \\ NaiveDateTime.utc_now())
  def last_24h_visitors_hourly_intervals([], _), do: %{}

  def last_24h_visitors_hourly_intervals(sites, now) do
    site_id_to_domain_mapping = for site <- sites, do: {site.id, site.domain}, into: %{}
    now = now |> NaiveDateTime.truncate(:second)

    placeholder = empty_24h_visitors_hourly_intervals(sites, now)

    previous_query = visitors_24h_total(now, -48, -24, site_id_to_domain_mapping)

    previous_result =
      previous_query
      |> ClickhouseRepo.all()
      |> Enum.reduce(%{}, fn
        %{total_visitors: total, site_id: site_id}, acc -> Map.put_new(acc, site_id, total)
      end)

    total_q = visitors_24h_total(now, -24, 0, site_id_to_domain_mapping)

    current_q =
      from(
        e in "events_v2",
        join: total_q in subquery(total_q),
        on: e.site_id == total_q.site_id,
        where: e.site_id in ^Map.keys(site_id_to_domain_mapping),
        where: e.timestamp >= ^NaiveDateTime.add(now, -24, :hour),
        where: e.timestamp <= ^now,
        select: %{
          site_id: e.site_id,
          interval: fragment("toStartOfHour(timestamp)"),
          visitors: uniq(e.user_id),
          total: fragment("any(total_visitors)")
        },
        group_by: [e.site_id, fragment("toStartOfHour(timestamp)")],
        order_by: [e.site_id, fragment("toStartOfHour(timestamp)")]
      )

    on_full_build do
      current_q = Plausible.Stats.Sampling.add_query_hint(current_q)
    end

    result =
      current_q
      |> ClickhouseRepo.all()
      |> Enum.group_by(& &1.site_id)
      |> Enum.map(fn {site_id, entries} ->
        %{total: visitors} = List.first(entries)

        full_entries =
          (entries ++ empty_24h_intervals(now))
          |> Enum.uniq_by(& &1.interval)
          |> Enum.sort_by(& &1.interval, NaiveDateTime)

        change = Plausible.Stats.Compare.percent_change(previous_result[site_id], visitors) || 100

        {site_id_to_domain_mapping[site_id],
         %{intervals: full_entries, visitors: visitors, change: change}}
      end)
      |> Map.new()

    Map.merge(placeholder, result)
  end

  defp visitors_24h_total(now, offset1, offset2, site_id_to_domain_mapping) do
    query =
      from e in "events_v2",
        where: e.site_id in ^Map.keys(site_id_to_domain_mapping),
        where: e.timestamp >= ^NaiveDateTime.add(now, offset1, :hour),
        where: e.timestamp <= ^NaiveDateTime.add(now, offset2, :hour),
        select: %{
          site_id: e.site_id,
          total_visitors: fragment("toUInt64(round(uniq(user_id) * any(_sample_factor)))")
        },
        group_by: [e.site_id]

    on_full_build do
      query = Plausible.Stats.Sampling.add_query_hint(query)
    end

    query
  end

  defp empty_24h_intervals(now) do
    first = NaiveDateTime.add(now, -23, :hour)
    {:ok, time} = Time.new(first.hour, 0, 0)
    first = NaiveDateTime.new!(NaiveDateTime.to_date(first), time)

    for offset <- 0..24 do
      %{
        interval: NaiveDateTime.add(first, offset, :hour),
        visitors: 0
      }
    end
  end

  defp base_session_query(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    q =
      from(s in "sessions_v2",
        where: s.site_id == ^site.id,
        where: s.timestamp >= ^first_datetime and s.start < ^last_datetime
      )

    on_full_build do
      q = Plausible.Stats.Sampling.add_query_hint(q, 10_000_000)
    end

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
    {first_datetime, last_datetime} = utc_boundaries(query, site)

    q =
      from(e in "events_v2",
        where: e.site_id == ^site.id,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    on_full_build do
      q = Plausible.Stats.Sampling.add_query_hint(q, 10_000_000)
    end

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
          where: not has_key(e, :meta, ^key)
        )
      else
        from(
          e in q,
          where: has_key(e, :meta, ^key) and get_by_key(e, :meta, ^key) == ^val
        )
      end
    else
      q
    end
  end

  defp base_query(site, query) do
    base_query_bare(site, query) |> include_goal_conversions(query)
  end

  defp utc_boundaries(%Query{period: "30m"}, site) do
    last_datetime = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    first_datetime =
      last_datetime
      |> Timex.shift(minutes: -30)
      |> beginning_of_time(site.native_stats_start_at)
      |> NaiveDateTime.truncate(:second)

    {first_datetime, last_datetime}
  end

  defp utc_boundaries(%Query{period: "realtime"}, site) do
    last_datetime = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    first_datetime =
      last_datetime
      |> Timex.shift(minutes: -5)
      |> beginning_of_time(site.native_stats_start_at)
      |> NaiveDateTime.truncate(:second)

    {first_datetime, last_datetime}
  end

  defp utc_boundaries(%Query{date_range: date_range}, site) do
    {:ok, first} = NaiveDateTime.new(date_range.first, ~T[00:00:00])

    first_datetime =
      first
      |> Timezones.to_utc_datetime(site.timezone)
      |> beginning_of_time(site.native_stats_start_at)

    {:ok, last} = NaiveDateTime.new(date_range.last |> Timex.shift(days: 1), ~T[00:00:00])

    last_datetime =
      Timezones.to_utc_datetime(last, site.timezone)

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

  defp beginning_of_time(candidate, site_creation_date) do
    if Timex.after?(site_creation_date, candidate) do
      site_creation_date
    else
      candidate
    end
  end
end
