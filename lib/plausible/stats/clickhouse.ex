defmodule Plausible.Stats.Clickhouse do
  use Plausible
  use Plausible.Repo
  use Plausible.ClickhouseRepo
  use Plausible.Stats.SQL.Fragments

  import Ecto.Query, only: [from: 2, dynamic: 1, dynamic: 2]

  alias Plausible.Timezones

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

  @spec imported_pageview_counts(Plausible.Site.t()) :: %{non_neg_integer() => non_neg_integer()}
  def imported_pageview_counts(site) do
    from(i in "imported_visitors",
      where: i.site_id == ^site.id,
      group_by: i.import_id,
      select: {i.import_id, sum(i.pageviews)}
    )
    |> Plausible.ClickhouseRepo.all()
    |> Map.new()
  end

  def usage_breakdown([sid | _] = site_ids, date_range) when is_integer(sid) do
    Enum.chunk_every(site_ids, 1000)
    |> Enum.map(fn site_ids ->
      fn ->
        ClickhouseRepo.one(
          from(e in "events_v2",
            where: e.site_id in ^site_ids,
            where: e.name != "pageleave",
            where: fragment("toDate(?)", e.timestamp) >= ^date_range.first,
            where: fragment("toDate(?)", e.timestamp) <= ^date_range.last,
            select: {
              fragment("countIf(? = 'pageview')", e.name),
              fragment("countIf(? != 'pageview')", e.name)
            }
          )
        )
      end
    end)
    |> ClickhouseRepo.parallel_tasks(max_concurrency: 10)
    |> Enum.reduce(fn {pageviews, custom_events}, {pageviews_total, custom_events_total} ->
      {pageviews_total + pageviews, custom_events_total + custom_events}
    end)
  end

  def usage_breakdown([], _date_range), do: {0, 0}

  def top_sources_for_spike(site, query, limit, page) do
    offset = (page - 1) * limit

    {first_datetime, last_datetime} = Plausible.Stats.Time.utc_boundaries(query)

    referrers =
      from(s in "sessions_v2",
        select: %{
          name: s.referrer_source,
          count: uniq(s.user_id)
        },
        where: s.site_id == ^site.id,
        # Note: This query intentionally uses session end timestamp to get currently active users
        where: s.timestamp >= ^first_datetime and s.start < ^last_datetime,
        where: s.referrer_source != "",
        group_by: s.referrer_source,
        order_by: [desc: uniq(s.user_id), asc: s.referrer_source],
        limit: ^limit,
        offset: ^offset
      )

    on_ee do
      referrers = Plausible.Stats.Sampling.add_query_hint(referrers, 10_000_000)
    end

    ClickhouseRepo.all(referrers)
  end

  def current_visitors(site) do
    Plausible.Stats.current_visitors(site)
  end

  def current_visitors_12h(site) do
    Plausible.Stats.current_visitors(site, Duration.new!(hour: -12))
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

  def has_pageleaves_last_30d?(site) do
    ClickhouseRepo.exists?(
      from(e in "events_v2",
        where:
          e.site_id == ^site.id and
            e.name == "pageleave" and
            e.timestamp >= ^NaiveDateTime.add(NaiveDateTime.utc_now(), -30, :day)
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

    base_query = base_24h_events_query(sites)

    previous_query = visitors_24h_total(base_query, now, -48, -24)

    previous_result =
      previous_query
      |> ClickhouseRepo.all()
      |> Enum.reduce(%{}, fn
        %{total_visitors: total, site_id: site_id}, acc -> Map.put_new(acc, site_id, total)
      end)

    total_q = visitors_24h_total(base_query, now, -24, 0)

    current_q =
      from(
        e in base_query,
        join: total_q in subquery(total_q),
        on: e.site_id == total_q.site_id,
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

    on_ee do
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

  defp visitors_24h_total(base_query, now, offset1, offset2) do
    query =
      from e in base_query,
        where: e.timestamp >= ^NaiveDateTime.add(now, offset1, :hour),
        where: e.timestamp <= ^NaiveDateTime.add(now, offset2, :hour),
        select: %{
          site_id: e.site_id,
          total_visitors: fragment("toUInt64(round(uniq(user_id) * any(_sample_factor)))")
        },
        group_by: [e.site_id]

    on_ee do
      query = Plausible.Stats.Sampling.add_query_hint(query)
    end

    query
  end

  defp base_24h_events_query(sites) do
    cutoff_times_condition =
      Enum.reduce(sites, dynamic(false), fn
        %{native_stats_start_at: nil}, dynamic ->
          dynamic

        site, dynamic ->
          dynamic(
            [e],
            ^dynamic or (e.site_id == ^site.id and e.timestamp >= ^site.native_stats_start_at)
          )
      end)

    from e in "events_v2",
      where: e.site_id in ^Enum.map(sites, & &1.id),
      where: ^cutoff_times_condition
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
end
