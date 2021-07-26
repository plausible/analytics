defmodule Plausible.Stats.Clickhouse do
  use Plausible.Repo
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.Query
  use Plausible.Stats.Fragments
  @no_ref "Direct / None"

  def compare_pageviews_and_visitors(site, query, {pageviews, visitors}) do
    query = Query.shift_back(query, site)
    {old_pageviews, old_visitors} = pageviews_and_visitors(site, query)

    cond do
      old_pageviews == 0 and pageviews > 0 ->
        {100, 100}

      old_pageviews == 0 and pageviews == 0 ->
        {0, 0}

      true ->
        {
          round((pageviews - old_pageviews) / old_pageviews * 100),
          round((visitors - old_visitors) / old_visitors * 100)
        }
    end
  end

  def calculate_plot(site, %Query{interval: "month"} = query) do
    n_steps = Timex.diff(query.date_range.last, query.date_range.first, :months)

    steps =
      Enum.map(n_steps..0, fn shift ->
        Timex.now(site.timezone)
        |> Timex.beginning_of_month()
        |> Timex.shift(months: -shift)
        |> DateTime.to_date()
      end)

    groups =
      ClickhouseRepo.all(
        from e in base_query_w_sessions(site, query),
          select:
            {fragment("toStartOfMonth(toTimeZone(?, ?)) as month", e.timestamp, ^site.timezone),
             uniq(e.user_id)},
          group_by: fragment("month"),
          order_by: fragment("month")
      )
      |> Enum.into(%{})

    present_index =
      Enum.find_index(steps, fn step ->
        step == Timex.now(site.timezone) |> Timex.to_date() |> Timex.beginning_of_month()
      end)

    plot = Enum.map(steps, fn step -> groups[step] || 0 end)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, labels, present_index}
  end

  def calculate_plot(site, %Query{interval: "date"} = query) do
    steps = Enum.into(query.date_range, [])

    groups =
      ClickhouseRepo.all(
        from e in base_query_w_sessions(site, query),
          select:
            {fragment("toDate(toTimeZone(?, ?)) as day", e.timestamp, ^site.timezone),
             uniq(e.user_id)},
          group_by: fragment("day"),
          order_by: fragment("day")
      )
      |> Enum.into(%{})

    present_index =
      Enum.find_index(steps, fn step -> step == Timex.now(site.timezone) |> Timex.to_date() end)

    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)
    plot = Enum.map(steps, fn step -> groups[step] || 0 end) |> Enum.take(steps_to_show)
    labels = Enum.map(steps, fn step -> Timex.format!(step, "{ISOdate}") end)

    {plot, labels, present_index}
  end

  def calculate_plot(site, %Query{interval: "hour"} = query) do
    steps = 0..23

    groups =
      ClickhouseRepo.all(
        from e in base_query_w_sessions(site, query),
          select:
            {fragment("toHour(toTimeZone(?, ?)) as hour", e.timestamp, ^site.timezone),
             uniq(e.user_id)},
          group_by: fragment("hour"),
          order_by: fragment("hour")
      )
      |> Enum.into(%{})

    now = Timex.now(site.timezone)
    is_today = Timex.to_date(now) == query.date_range.first
    present_index = is_today && Enum.find_index(steps, fn step -> step == now.hour end)
    steps_to_show = if present_index, do: present_index + 1, else: Enum.count(steps)

    labels =
      Enum.map(steps, fn step ->
        Timex.to_datetime(query.date_range.first)
        |> Timex.shift(hours: step)
        |> NaiveDateTime.to_iso8601()
      end)

    plot = Enum.map(steps, fn step -> groups[step] || 0 end) |> Enum.take(steps_to_show)
    {plot, labels, present_index}
  end

  def calculate_plot(site, %Query{period: "realtime"} = query) do
    query = %Query{query | period: "30m"}

    groups =
      ClickhouseRepo.all(
        from e in base_query_w_sessions(site, query),
          select: {
            fragment("dateDiff('minute', now(), ?) as relativeMinute", e.timestamp),
            total()
          },
          group_by: fragment("relativeMinute"),
          order_by: fragment("relativeMinute")
      )
      |> Enum.into(%{})

    labels = Enum.into(-30..-1, [])
    plot = Enum.map(labels, fn label -> groups[label] || 0 end)
    {plot, labels, nil}
  end

  def bounce_rate(site, query) do
    q = base_session_query(site, query) |> apply_page_as_entry_page(site, query)

    ClickhouseRepo.one(
      from s in q,
        select: bounce_rate()
    ) || 0
  end

  def visit_duration(site, query) do
    q = base_session_query(site, query) |> apply_page_as_entry_page(site, query)

    ClickhouseRepo.one(
      from s in q,
        select: visit_duration()
    ) || 0
  end

  def total_pageviews(site, %Query{period: "realtime"} = query) do
    query = %Query{query | period: "30m"}

    q = base_session_query(site, query) |> apply_page_as_entry_page(site, query)

    ClickhouseRepo.one(
      from e in q,
        select: fragment("sum(sign * pageviews)")
    )
  end

  def total_pageviews(site, query) do
    ClickhouseRepo.one(
      from e in base_query_w_sessions(site, query),
        select: total()
    )
  end

  def total_events(site, query) do
    ClickhouseRepo.one(
      from e in base_query_w_sessions(site, query),
        select: total()
    )
  end

  def usage(site) do
    q = Plausible.Stats.Query.from(site.timezone, %{"period" => "30d"})
    {first_datetime, last_datetime} = utc_boundaries(q, site.timezone)

    ClickhouseRepo.all(
      from e in "events",
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime,
        group_by: fragment("name"),
        select: {
          fragment("if(? = 'pageview', 'pageviews', 'custom_events') as name", e.name),
          fragment("count(*)")
        }
    )
    |> Enum.into(%{})
  end

  def pageviews_and_visitors(site, query) do
    {pageviews, visitors, _} = pageviews_and_visitors_with_sample_percent(site, query)
    {pageviews, visitors}
  end

  def pageviews_and_visitors_with_sample_percent(site, query) do
    ClickhouseRepo.one(
      from e in base_query_w_sessions(site, query),
        select: {total(), uniq(e.user_id), sample_percent()}
    )
  end

  def unique_visitors(site, query) do
    {visitors, _} = unique_visitors_with_sample_percent(site, query)
    visitors
  end

  def unique_visitors_with_sample_percent(site, query) do
    query = if query.period == "realtime", do: %Query{query | period: "30m"}, else: query

    ClickhouseRepo.one(
      from e in base_query_w_sessions(site, query),
        select: {uniq(e.user_id), sample_percent()}
    )
  end

  def top_referrers_for_goal(site, query, limit, page) do
    offset = (page - 1) * limit

    ClickhouseRepo.all(
      from s in base_query_w_sessions(site, query),
        where: s.referrer_source != "",
        group_by: s.referrer_source,
        order_by: [desc: uniq(s.user_id)],
        limit: ^limit,
        offset: ^offset,
        select: %{
          name: s.referrer_source,
          url: fragment("any(?)", s.referrer),
          count: uniq(s.user_id)
        }
    )
    |> Enum.map(fn ref ->
      Map.update(ref, :url, nil, fn url -> url && URI.parse("http://" <> url).host end)
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
    page = query.filters["page"]

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
    include_path_filter_entry(db_query, query.filters["page"])
  end

  def utm_mediums(site, query, limit \\ 9, page \\ 1, show_noref \\ false) do
    offset = (page - 1) * limit

    q =
      from(
        s in base_session_query(site, query),
        group_by: s.utm_medium,
        order_by: [desc: uniq(s.user_id), asc: min(s.start)],
        limit: ^limit,
        offset: ^offset,
        select: %{
          name: coalesce_string(s.utm_medium, @no_ref),
          count: uniq(s.user_id),
          bounce_rate: bounce_rate(),
          visit_duration: visit_duration()
        }
      )

    q =
      if show_noref do
        q
      else
        from(s in q, where: s.utm_medium != "")
      end

    q
    |> filter_converted_sessions(site, query)
    |> ClickhouseRepo.all()
  end

  def utm_campaigns(site, query, limit \\ 9, page \\ 1, show_noref \\ false) do
    offset = (page - 1) * limit

    q =
      from(
        s in base_session_query(site, query),
        group_by: s.utm_campaign,
        order_by: [desc: uniq(s.user_id), asc: min(s.start)],
        limit: ^limit,
        offset: ^offset,
        select: %{
          name: coalesce_string(s.utm_campaign, @no_ref),
          count: uniq(s.user_id),
          bounce_rate: bounce_rate(),
          visit_duration: visit_duration()
        }
      )

    q =
      if show_noref do
        q
      else
        from(s in q, where: s.utm_campaign != "")
      end

    q
    |> filter_converted_sessions(site, query)
    |> ClickhouseRepo.all()
  end

  def utm_sources(site, query, limit \\ 9, page \\ 1, show_noref \\ false) do
    offset = (page - 1) * limit

    q =
      from(
        s in base_session_query(site, query),
        group_by: s.utm_source,
        order_by: [desc: uniq(s.user_id), asc: min(s.start)],
        limit: ^limit,
        offset: ^offset,
        select: %{
          name: coalesce_string(s.utm_source, @no_ref),
          count: uniq(s.user_id),
          bounce_rate: bounce_rate(),
          visit_duration: visit_duration()
        }
      )

    q =
      if show_noref do
        q
      else
        from(s in q, where: s.utm_source != "")
      end

    q
    |> filter_converted_sessions(site, query)
    |> ClickhouseRepo.all()
  end

  def conversions_from_referrer(site, query, referrer) do
    converted_sessions =
      from(
        from e in base_query(site, query),
          select: %{session_id: e.session_id}
      )

    ClickhouseRepo.one(
      from s in Plausible.ClickhouseSession,
        join: cs in subquery(converted_sessions),
        on: s.session_id == cs.session_id,
        where: s.referrer_source == ^referrer,
        select: uniq(s.user_id)
    )
  end

  def referrer_drilldown(site, query, referrer, include_details, limit) do
    referrer = if referrer == @no_ref, do: "", else: referrer

    q =
      from(
        s in base_session_query(site, query),
        group_by: s.referrer,
        where: s.referrer_source == ^referrer,
        order_by: [desc: uniq(s.user_id)],
        limit: ^limit
      )
      |> filter_converted_sessions(site, query)

    q =
      if include_details do
        from(
          s in q,
          select: %{
            name: coalesce_string(s.referrer, @no_ref),
            count: uniq(s.user_id),
            bounce_rate: bounce_rate(),
            visit_duration: visit_duration()
          }
        )
      else
        from(s in q,
          select: %{
            name: coalesce_string(s.referrer, @no_ref),
            count: uniq(s.user_id)
          }
        )
      end

    referring_urls =
      ClickhouseRepo.all(q)
      |> Enum.map(fn ref ->
        url = if ref[:name] !== "", do: URI.parse("http://" <> ref[:name]).host
        Map.put(ref, :url, url)
      end)

    if referrer == "Twitter" do
      urls = Enum.map(referring_urls, & &1[:name])

      tweets =
        Repo.all(
          from t in Plausible.Twitter.Tweet,
            where: t.link in ^urls
        )
        |> Enum.group_by(& &1.link)

      Enum.map(referring_urls, fn url ->
        Map.put(url, :tweets, tweets[url[:name]])
      end)
    else
      referring_urls
    end
  end

  def referrer_drilldown_for_goal(site, query, referrer) do
    Plausible.ClickhouseRepo.all(
      from s in base_query_w_sessions(site, query),
        where: s.referrer_source == ^referrer,
        group_by: s.referrer,
        order_by: [desc: uniq(s.user_id)],
        limit: 100,
        select: %{
          name: s.referrer,
          count: uniq(s.user_id)
        }
    )
  end

  def entry_pages(site, query, limit, page \\ 1) do
    offset = (page - 1) * limit

    q =
      from(
        s in base_session_query(site, query),
        group_by: s.entry_page,
        order_by: [desc: uniq(s.user_id)],
        limit: ^limit,
        offset: ^offset,
        select: %{
          name: s.entry_page,
          count: uniq(s.user_id),
          entries: uniq(s.session_id),
          visit_duration: visit_duration()
        }
      )
      |> filter_converted_sessions(site, query)

    ClickhouseRepo.all(q)
  end

  def exit_pages(site, query, limit, page \\ 1) do
    offset = (page - 1) * limit

    q =
      from(
        s in base_session_query(site, query),
        group_by: s.exit_page,
        order_by: [desc: uniq(s.user_id)],
        limit: ^limit,
        offset: ^offset,
        where: s.exit_page != "",
        select: %{
          name: s.exit_page,
          count: uniq(s.user_id),
          exits: uniq(s.session_id)
        }
      )
      |> filter_converted_sessions(site, query)

    result = ClickhouseRepo.all(q)

    if Enum.count(result) > 0 do
      pages = Enum.map(result, fn r -> r[:name] end)

      event_q =
        from(e in base_query_w_session_based_pageviews(site, query),
          group_by: e.pathname,
          where: fragment("? IN tuple(?)", e.pathname, ^pages),
          where: e.name == "pageview",
          select: {
            e.pathname,
            total()
          }
        )

      total_pageviews = ClickhouseRepo.all(event_q) |> Enum.into(%{})

      Enum.map(result, fn r ->
        if Map.get(total_pageviews, r[:name]) do
          exit_rate = r[:exits] / Map.get(total_pageviews, r[:name]) * 100
          Map.put(r, :exit_rate, Float.floor(exit_rate))
        else
          Map.put(r, :exit_rate, nil)
        end
      end)
    else
      result
    end
  end

  def top_pages(site, %Query{period: "realtime"} = query, limit, page, _include_details) do
    offset = (page - 1) * limit

    q = base_session_query(site, query) |> apply_page_as_entry_page(site, query)

    ClickhouseRepo.all(
      from s in q,
        group_by: s.exit_page,
        order_by: [desc: uniq(s.user_id)],
        limit: ^limit,
        offset: ^offset,
        select: %{
          name: s.exit_page,
          count: uniq(s.user_id)
        }
    )
  end

  def top_pages(site, query, limit, page, include_details) do
    offset = (page - 1) * limit

    q =
      from(
        e in base_query_w_sessions(site, query),
        group_by: e.pathname,
        order_by: [desc: uniq(e.user_id)],
        limit: ^limit,
        offset: ^offset,
        select: %{
          name: e.pathname,
          count: uniq(e.user_id),
          pageviews: total()
        }
      )

    pages = ClickhouseRepo.all(q)

    if include_details do
      [{bounce_state, bounce_result}, {time_state, time_result}] =
        Task.yield_many(
          [
            Task.async(fn -> bounce_rates_by_page_url(site, query) end),
            Task.async(fn ->
              {:ok, page_times} =
                page_times_by_page_url(site, query, Enum.map(pages, fn p -> p.name end))

              page_times.rows |> Enum.map(fn [a, b] -> {a, b} end) |> Enum.into(%{})
            end)
          ],
          15000
        )
        |> Enum.map(fn {task, response} ->
          case response do
            nil ->
              Task.shutdown(task, :brutal_kill)
              {nil, nil}

            {:ok, result} ->
              {:ok, result}

            _ ->
              response
          end
        end)

      Enum.map(pages, fn page ->
        if bounce_state == :ok,
          do: Map.put(page, :bounce_rate, bounce_result[page[:name]]),
          else: page
      end)
      |> Enum.map(fn page ->
        if time_state == :ok do
          time = time_result[page[:name]]

          Map.put(
            page,
            :time_on_page,
            if(time, do: round(time), else: nil)
          )
        else
          page
        end
      end)
    else
      pages
    end
  end

  defp bounce_rates_by_page_url(site, query) do
    q = base_session_query(site, query) |> apply_page_as_entry_page(site, query)

    ClickhouseRepo.all(
      from s in q,
        group_by: s.entry_page,
        order_by: [desc: total()],
        limit: 100,
        select: %{
          entry_page: s.entry_page,
          total: total(),
          bounce_rate: bounce_rate()
        }
    )
    |> Enum.map(fn row -> {row[:entry_page], row[:bounce_rate]} end)
    |> Enum.into(%{})
  end

  def page_times_by_page_url(site, query, page_list \\ nil)

  def page_times_by_page_url(site, query, _page_list = nil) do
    {negated, updated_page_selection} = query.filters["page"] |> check_negated_filter()
    {_, page_regex} = updated_page_selection |> convert_path_regex()

    q =
      from(
        e in base_query_w_sessions(site, %Query{
          query
          | filters: Map.delete(query.filters, "page")
        }),
        select: {
          fragment("? as p", e.pathname),
          fragment("? as t", e.timestamp),
          fragment("? as s", e.session_id)
        },
        order_by: [e.session_id, e.timestamp]
      )

    {base_query_raw, base_query_raw_params} = ClickhouseRepo.to_sql(:all, q)

    time_query = "
      SELECT
        avg(ifNotFinite(avgTime, null))
      FROM
        (SELECT
          p,
          sum(td)/count(case when p2 != p then 1 end) as avgTime
        FROM
          (SELECT
            p,
            p2,
            sum(t2-t) as td
          FROM
            (SELECT
              *,
              neighbor(t, 1) as t2,
              neighbor(p, 1) as p2,
              neighbor(s, 1) as s2
            FROM (#{base_query_raw}))
          WHERE s=s2 AND
          #{if negated, do: "not(match(p, ?))", else: "match(p, ?)"}
          GROUP BY p,p2,s)
        GROUP BY p)"

    time_query |> ClickhouseRepo.query(base_query_raw_params ++ [page_regex])
  end

  def page_times_by_page_url(site, query, page_list) do
    q =
      from(
        e in base_query_w_sessions(site, %Query{
          query
          | filters: Map.delete(query.filters, "page")
        }),
        select: {
          fragment("? as p", e.pathname),
          fragment("? as t", e.timestamp),
          fragment("? as s", e.session_id)
        },
        order_by: [e.session_id, e.timestamp]
      )

    {base_query_raw, base_query_raw_params} = ClickhouseRepo.to_sql(:all, q)

    time_query = "
      SELECT
        p,
        sum(td)/count(case when p2 != p then 1 end) as avgTime
      FROM
        (SELECT
          p,
          p2,
          sum(t2-t) as td
        FROM
          (SELECT
            *,
            neighbor(t, 1) as t2,
            neighbor(p, 1) as p2,
            neighbor(s, 1) as s2
          FROM (#{base_query_raw}))
        WHERE s=s2 AND p IN tuple(?)
        GROUP BY p,p2,s)
      GROUP BY p"

    time_query
    |> ClickhouseRepo.query(
      base_query_raw_params ++ [(Enum.count(page_list) > 0 && page_list) || ["/"]]
    )
  end

  defp add_percentages(stat_list) do
    total = Enum.reduce(stat_list, 0, fn %{count: count}, total -> total + count end)

    Enum.map(stat_list, fn stat ->
      Map.put(stat, :percentage, round(stat[:count] / total * 100))
    end)
  end

  def top_screen_sizes(site, query) do
    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.screen_size,
        where: e.screen_size != "",
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name: e.screen_size,
          count: uniq(e.user_id)
        }
    )
    |> add_percentages
  end

  def countries(site, query) do
    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.country_code,
        where: e.country_code != "\0\0",
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name: e.country_code,
          count: uniq(e.user_id)
        }
    )
    |> Enum.map(fn stat ->
      two_letter_code = stat[:name]

      stat
      |> Map.put(:name, Plausible.Stats.CountryName.to_alpha3(two_letter_code))
      |> Map.put(:full_country_name, Plausible.Stats.CountryName.from_iso3166(two_letter_code))
    end)
    |> add_percentages
  end

  def subdivisions1(site, query, country_name) do
    country = Plausible.Stats.CountryName.to_alpha2(country_name)

    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.country_code,
        group_by: e.subdivision1_geoname_id,
        where: e.country_code == ^country,
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name:
            fragment(
              "if(? = '', 'Other', subdivision1_geoname_id) as subdivision1_geoname_id",
              e.subdivision1_geoname_id
            ),
          count: uniq(e.user_id)
        }
    )
    |> add_percentages
  end

  def subdivisions2(site, query, country_name, subdivision1_geoname_id) do
    country = Plausible.Stats.CountryName.to_alpha2(country_name)
    subdivision1 = if subdivision1_geoname_id != "Other", do: subdivision1_geoname_id, else: ""

    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.country_code,
        group_by: e.subdivision1_geoname_id,
        group_by: e.subdivision2_geoname_id,
        where: e.country_code == ^country,
        where: e.subdivision1_geoname_id == ^subdivision1,
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name:
            fragment(
              "if(? = '', 'Other', subdivision2_geoname_id) as subdivision2_geoname_id",
              e.subdivision2_geoname_id
            ),
          count: uniq(e.user_id)
        }
    )
    |> add_percentages
  end

  def cities(site, query, country_name, subdivision1_geoname_id, subdivision2_geoname_id) do
    country = Plausible.Stats.CountryName.to_alpha2(country_name)
    subdivision1 = if subdivision1_geoname_id != "Other", do: subdivision1_geoname_id, else: ""
    subdivision2 = if subdivision2_geoname_id != "Other", do: subdivision2_geoname_id, else: ""

    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.country_code,
        group_by: e.subdivision1_geoname_id,
        group_by: e.subdivision2_geoname_id,
        group_by: e.city_geoname_id,
        where: e.country_code == ^country,
        where: e.subdivision1_geoname_id == ^subdivision1,
        where: e.subdivision2_geoname_id == ^subdivision2,
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name:
            fragment("if(? = '', 'NA', city_geoname_id) as city_geoname_id", e.city_geoname_id),
          count: uniq(e.user_id)
        }
    )
    |> add_percentages
  end

  def browsers(site, query, limit \\ 5) do
    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.browser,
        where: e.browser != "",
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name: e.browser,
          count: uniq(e.user_id)
        }
    )
    |> add_percentages
    |> Enum.take(limit)
  end

  def browser_versions(site, query, limit \\ 5) do
    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.browser_version,
        where: e.browser_version != "",
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name: e.browser_version,
          count: uniq(e.user_id)
        }
    )
    |> add_percentages
    |> Enum.take(limit)
  end

  def operating_systems(site, query, limit \\ 5) do
    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.operating_system,
        where: e.operating_system != "",
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name: e.operating_system,
          count: uniq(e.user_id)
        }
    )
    |> add_percentages
    |> Enum.take(limit)
  end

  def operating_system_versions(site, query, limit \\ 5) do
    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.operating_system_version,
        where: e.operating_system_version != "",
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name: e.operating_system_version,
          count: uniq(e.user_id)
        }
    )
    |> add_percentages
    |> Enum.take(limit)
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
    ClickhouseRepo.exists?(from e in "events", where: e.domain == ^site.domain)
  end

  def all_props(site, %Query{filters: %{"props" => meta}} = query) when is_map(meta) do
    [{key, val}] = meta |> Enum.into([])

    if val == "(none)" do
      goal = query.filters["goal"]
      %{goal => [key]}
    else
      ClickhouseRepo.all(
        from [e, meta: meta] in base_query_w_sessions_bare(site, query),
          select: {e.name, meta.key},
          distinct: true
      )
      |> Enum.reduce(%{}, fn {goal_name, meta_key}, acc ->
        Map.update(acc, goal_name, [meta_key], fn list -> [meta_key | list] end)
      end)
    end
  end

  def all_props(site, query) do
    ClickhouseRepo.all(
      from e in base_query_w_sessions_bare(site, query),
        inner_lateral_join: meta in fragment("meta as m"),
        select: {e.name, meta.key},
        distinct: true
    )
    |> Enum.reduce(%{}, fn {goal_name, meta_key}, acc ->
      Map.update(acc, goal_name, [meta_key], fn list -> [meta_key | list] end)
    end)
  end

  def property_breakdown(site, %Query{filters: %{"props" => meta}} = query, key)
      when is_map(meta) do
    [{_key, val}] = meta |> Enum.into([])

    if val == "(none)" do
      ClickhouseRepo.all(
        from e in base_query_w_sessions(site, query),
          where: fragment("not has(meta.key, ?)", ^key),
          order_by: [desc: uniq(e.user_id)],
          select: %{
            name: "(none)",
            count: uniq(e.user_id),
            total_count: total()
          }
      )
    else
      ClickhouseRepo.all(
        from [e, meta: meta] in base_query_w_sessions(site, query),
          group_by: meta.value,
          order_by: [desc: uniq(e.user_id)],
          select: %{
            name: meta.value,
            count: uniq(e.user_id),
            total_count: total()
          }
      )
    end
  end

  def property_breakdown(site, query, key) do
    none =
      ClickhouseRepo.all(
        from e in base_query_w_sessions(site, query),
          where: fragment("not has(?.key, ?)", e.meta, ^key),
          select: %{
            name: "(none)",
            count: uniq(e.user_id),
            total_count: total()
          }
      )

    values =
      ClickhouseRepo.all(
        from e in base_query_w_sessions(site, query),
          inner_lateral_join: meta in fragment("meta as m"),
          where: meta.key == ^key,
          group_by: meta.value,
          order_by: [desc: uniq(e.user_id)],
          select: %{
            name: meta.value,
            count: uniq(e.user_id),
            total_count: total()
          }
      )

    (values ++ none)
    |> Enum.sort(fn row1, row2 -> row1[:count] >= row2[:count] end)
    |> Enum.filter(fn row -> row[:count] > 0 end)
    |> Enum.map(fn row ->
      uri = URI.parse(row[:name])

      if uri.host && uri.scheme do
        Map.put(row, :is_url, true)
      else
        row
      end
    end)
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

  def goal_conversions(site, %Query{filters: %{"goal" => goal}} = query) when is_binary(goal) do
    ClickhouseRepo.all(
      from e in base_query_w_sessions(site, query),
        group_by: e.name,
        order_by: [desc: uniq(e.user_id)],
        select: %{
          name: ^goal,
          count: uniq(e.user_id),
          total_count: total()
        }
    )
  end

  def goal_conversions(site, query) do
    goals = Repo.all(from g in Plausible.Goal, where: g.domain == ^site.domain)
    query = if query.period == "realtime", do: %Query{query | period: "30m"}, else: query

    (fetch_pageview_goals(goals, site, query) ++
       fetch_event_goals(goals, site, query))
    |> sort_conversions()
  end

  defp fetch_event_goals(goals, site, query) do
    events =
      Enum.map(goals, fn goal -> goal.event_name end)
      |> Enum.filter(& &1)

    if Enum.count(events) > 0 do
      q =
        from(
          e in base_query_w_sessions_bare(site, query),
          where: fragment("? IN tuple(?)", e.name, ^events),
          group_by: e.name,
          select: %{
            name: e.name,
            count: uniq(e.user_id),
            total_count: total()
          }
        )

      ClickhouseRepo.all(q)
    else
      []
    end
  end

  defp fetch_pageview_goals(goals, site, query) do
    goals =
      Enum.map(goals, fn goal -> goal.page_path end)
      |> Enum.filter(& &1)

    if Enum.count(goals) > 0 do
      regex_goals =
        Enum.map(goals, fn g ->
          "^#{g}\/?$"
          |> String.replace(~r/\*\*/, ".*")
          |> String.replace(~r/(?<!\.)\*/, "[^/]*")
        end)

      from(
        e in base_query_w_sessions(site, query),
        where:
          fragment(
            "notEmpty(multiMatchAllIndices(?, array(?)) as indices)",
            e.pathname,
            ^regex_goals
          ),
        select: %{
          index: fragment("arrayJoin(indices) as index"),
          count: uniq(e.user_id),
          total_count: total()
        },
        group_by: fragment("index")
      )
      |> ClickhouseRepo.all()
      |> Enum.map(fn x ->
        Map.put(x, :name, "Visit #{Enum.at(goals, x[:index] - 1)}") |> Map.delete(:index)
      end)
    else
      []
    end
  end

  defp sort_conversions(conversions) do
    Enum.sort_by(conversions, fn conversion -> -conversion[:count] end)
  end

  defp base_query_w_sessions_bare(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    sessions_q =
      from(s in "sessions",
        hints: ["SAMPLE 10000000"],
        where: s.domain == ^site.domain,
        where: s.timestamp >= ^first_datetime and s.start < ^last_datetime,
        select: %{session_id: s.session_id}
      )

    sessions_q =
      if query.filters["source"] do
        source = query.filters["source"]
        source = if source == @no_ref, do: "", else: source
        from(s in sessions_q, where: s.referrer_source == ^source)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["screen"] do
        size = query.filters["screen"]
        from(s in sessions_q, where: s.screen_size == ^size)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["browser"] do
        browser = query.filters["browser"]
        from(s in sessions_q, where: s.browser == ^browser)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["browser_version"] do
        version = query.filters["browser_version"]
        from(s in sessions_q, where: s.browser_version == ^version)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["os"] do
        os = query.filters["os"]
        from(s in sessions_q, where: s.operating_system == ^os)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["os_version"] do
        version = query.filters["os_version"]
        from(s in sessions_q, where: s.operating_system_version == ^version)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["country"] do
        country = Plausible.Stats.CountryName.to_alpha2(query.filters["country"])
        from(s in sessions_q, where: s.country_code == ^country)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["utm_medium"] do
        utm_medium = query.filters["utm_medium"]
        from(s in sessions_q, where: s.utm_medium == ^utm_medium)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["utm_source"] do
        utm_source = query.filters["utm_source"]
        from(s in sessions_q, where: s.utm_source == ^utm_source)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["utm_campaign"] do
        utm_campaign = query.filters["utm_campaign"]
        from(s in sessions_q, where: s.utm_campaign == ^utm_campaign)
      else
        sessions_q
      end

    sessions_q =
      if query.filters["referrer"] do
        ref = query.filters["referrer"]
        from(s in sessions_q, where: s.referrer == ^ref)
      else
        sessions_q
      end

    sessions_q = include_path_filter_entry(sessions_q, query.filters["entry_page"])

    sessions_q = include_path_filter_exit(sessions_q, query.filters["exit_page"])

    q =
      from(e in "events",
        hints: ["SAMPLE 10000000"],
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    q =
      if query.filters["source"] || query.filters["referrer"] || query.filters["utm_medium"] ||
           query.filters["utm_source"] || query.filters["utm_campaign"] || query.filters["screen"] ||
           query.filters["browser"] || query.filters["browser_version"] || query.filters["os"] ||
           query.filters["os_version"] || query.filters["country"] || query.filters["entry_page"] ||
           query.filters["exit_page"] do
        from(
          e in q,
          join: sq in subquery(sessions_q),
          on: e.session_id == sq.session_id
        )
      else
        q
      end

    q = include_path_filter(q, query.filters["page"])

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
          as: :meta,
          where: meta.key == ^key and meta.value == ^val
        )
      end
    else
      q
    end
  end

  defp base_query_w_session_based_pageviews(site, query) do
    {first_datetime, last_datetime} = utc_boundaries(query, site.timezone)

    sessions_q = base_session_query(site, query) |> filter_converted_sessions(site, query)

    sessions_q =
      from(s in sessions_q,
        select: %{session_id: s.session_id}
      )

    q =
      from(e in "events",
        hints: ["SAMPLE 10000000"],
        where: e.domain == ^site.domain,
        where: e.timestamp >= ^first_datetime and e.timestamp < ^last_datetime
      )

    if query.filters["source"] || query.filters["referrer"] || query.filters["utm_medium"] ||
         query.filters["utm_source"] || query.filters["utm_campaign"] || query.filters["screen"] ||
         query.filters["browser"] || query.filters["browser_version"] || query.filters["os"] ||
         query.filters["os_version"] || query.filters["country"] || query.filters["entry_page"] ||
         query.filters["exit_page"] || query.filters["page"] || query.filters["goal"] do
      from(
        e in q,
        join: sq in subquery(sessions_q),
        on: e.session_id == sq.session_id
      )
    else
      q
    end
  end

  defp base_query_w_sessions(site, query) do
    base_query_w_sessions_bare(site, query) |> include_goal_conversions(query)
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
        country = Plausible.Stats.CountryName.to_alpha2(query.filters["country"])
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
        country = Plausible.Stats.CountryName.to_alpha2(query.filters["country"])
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
      if query.filters["referrer"] do
        ref = query.filters["referrer"]
        from(e in q, where: e.referrer == ^ref)
      else
        q
      end

    q = include_path_filter(q, query.filters["page"])

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

  def make_suggestions(site, query, "country", filter_search) do
    filter_search =
      String.split(filter_search, ",")
      |> Enum.map(fn c -> Plausible.Stats.CountryName.to_alpha2(c) end)

    q =
      from(
        e in base_session_query(site, query),
        group_by: e.country_code,
        order_by: [desc: fragment("count(*)")],
        select: {e.country_code}
      )

    ClickhouseRepo.all(q)
    |> Enum.map(fn {x} -> x end)
    |> Enum.filter(fn c -> Enum.find(filter_search, false, fn x -> x == c end) end)
    |> Enum.map(fn c -> Plausible.Stats.CountryName.to_alpha3(c) end)
    |> Enum.slice(0..24)
  end

  def make_suggestions(site, _query, "goal", filter_search) do
    Repo.all(from g in Plausible.Goal, where: g.domain == ^site.domain)
    |> Enum.map(fn x -> if x.event_name, do: x.event_name, else: "Visit #{x.page_path}" end)
    |> Enum.filter(fn goal ->
      String.contains?(
        String.downcase(goal),
        String.downcase(filter_search)
      )
    end)
  end

  def make_suggestions(site, query, filter_name, filter_search) do
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
        do: base_query(site, query),
        else: base_session_query(site, query)
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
