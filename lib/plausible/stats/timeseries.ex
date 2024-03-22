defmodule Plausible.Stats.Timeseries do
  use Plausible.ClickhouseRepo
  use Plausible
  alias Plausible.Stats.{Query, Util}
  import Plausible.Stats.{Base}
  import Ecto.Query
  use Plausible.Stats.Fragments

  @typep metric ::
           :pageviews
           | :events
           | :visitors
           | :visits
           | :bounce_rate
           | :visit_duration
           | :average_revenue
           | :total_revenue
  @typep value :: nil | integer() | float()
  @type results :: nonempty_list(%{required(:date) => Date.t(), required(metric()) => value()})

  @revenue_metrics on_full_build(do: Plausible.Stats.Goal.Revenue.revenue_metrics(), else: [])

  @event_metrics [:visitors, :pageviews, :events, :conversion_rate] ++ @revenue_metrics
  @session_metrics [:visits, :bounce_rate, :visit_duration, :views_per_visit]
  def timeseries(site, query, metrics) do
    steps = buckets(query)

    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))

    {currency, event_metrics} =
      on_full_build do
        Plausible.Stats.Goal.Revenue.get_revenue_tracking_currency(site, query, event_metrics)
      else
        {nil, event_metrics}
      end

    Query.trace(query, metrics)

    [event_result, session_result] =
      Plausible.ClickhouseRepo.parallel_tasks([
        fn -> events_timeseries(site, query, event_metrics) end,
        fn -> sessions_timeseries(site, query, session_metrics) end
      ])

    Enum.map(steps, fn step ->
      empty_row(step, metrics)
      |> Map.merge(Enum.find(event_result, fn row -> date_eq(row[:date], step) end) || %{})
      |> Map.merge(Enum.find(session_result, fn row -> date_eq(row[:date], step) end) || %{})
      |> Map.update!(:date, &date_format/1)
      |> cast_revenue_metrics_to_money(currency)
    end)
    |> Util.keep_requested_metrics(metrics)
  end

  defp events_timeseries(_, _, []), do: []

  defp events_timeseries(site, query, metrics) do
    metrics = Util.maybe_add_visitors_metric(metrics)

    from(e in base_event_query(site, query), select: ^select_event_metrics(metrics))
    |> select_bucket(site, query)
    |> maybe_add_timeseries_conversion_rate(site, query, metrics)
    |> Plausible.Stats.Imported.merge_imported_timeseries(site, query, metrics)
    |> ClickhouseRepo.all()
  end

  defp sessions_timeseries(_, _, []), do: []

  defp sessions_timeseries(site, query, metrics) do
    from(e in query_sessions(site, query), select: ^select_session_metrics(metrics, query))
    |> filter_converted_sessions(site, query)
    |> select_bucket(site, query)
    |> Plausible.Stats.Imported.merge_imported_timeseries(site, query, metrics)
    |> ClickhouseRepo.all()
    |> Util.keep_requested_metrics(metrics)
  end

  defp buckets(%Query{interval: "month"} = query) do
    n_buckets = Timex.diff(query.date_range.last, query.date_range.first, :months)

    Enum.map(n_buckets..0, fn shift ->
      query.date_range.last
      |> Timex.beginning_of_month()
      |> Timex.shift(months: -shift)
    end)
  end

  defp buckets(%Query{interval: "week"} = query) do
    n_buckets = Timex.diff(query.date_range.last, query.date_range.first, :weeks)

    Enum.map(0..n_buckets, fn shift ->
      query.date_range.first
      |> Timex.shift(weeks: shift)
      |> date_or_weekstart(query)
    end)
  end

  defp buckets(%Query{interval: "date"} = query) do
    Enum.into(query.date_range, [])
  end

  @full_day_in_hours 23
  defp buckets(%Query{interval: "hour"} = query) do
    n_buckets =
      Timex.diff(query.date_range.last, query.date_range.first, :hours) + @full_day_in_hours

    Enum.map(0..n_buckets, fn step ->
      query.date_range.first
      |> Timex.to_datetime()
      |> Timex.shift(hours: step)
    end)
  end

  defp buckets(%Query{period: "30m", interval: "minute"}) do
    Enum.into(-30..-1, [])
  end

  @full_day_in_minutes 1439
  defp buckets(%Query{interval: "minute"} = query) do
    n_buckets =
      if query.date_range.first == query.date_range.last do
        @full_day_in_minutes
      else
        Timex.diff(query.date_range.last, query.date_range.first, :minutes)
      end

    Enum.map(0..n_buckets, fn step ->
      query.date_range.first
      |> Timex.to_datetime()
      |> Timex.shift(minutes: step)
    end)
  end

  defp date_eq(%DateTime{} = left, %DateTime{} = right) do
    NaiveDateTime.compare(left, right) == :eq
  end

  defp date_eq(%Date{} = left, %Date{} = right) do
    Date.compare(left, right) == :eq
  end

  defp date_eq(left, right) do
    left == right
  end

  defp date_format(%DateTime{} = date) do
    Timex.format!(date, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
  end

  defp date_format(date) do
    date
  end

  defp select_bucket(q, site, %Query{interval: "month"}) do
    from(
      e in q,
      group_by: fragment("toStartOfMonth(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      order_by: fragment("toStartOfMonth(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      select_merge: %{
        date: fragment("toStartOfMonth(toTimeZone(?, ?))", e.timestamp, ^site.timezone)
      }
    )
  end

  defp select_bucket(q, site, %Query{interval: "week"} = query) do
    {first_datetime, _} = utc_boundaries(query, site)

    from(
      e in q,
      select_merge: %{date: weekstart_not_before(e.timestamp, ^first_datetime, ^site.timezone)},
      group_by: weekstart_not_before(e.timestamp, ^first_datetime, ^site.timezone),
      order_by: weekstart_not_before(e.timestamp, ^first_datetime, ^site.timezone)
    )
  end

  defp select_bucket(q, site, %Query{interval: "date"}) do
    from(
      e in q,
      group_by: fragment("toDate(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      order_by: fragment("toDate(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      select_merge: %{
        date: fragment("toDate(toTimeZone(?, ?))", e.timestamp, ^site.timezone)
      }
    )
  end

  defp select_bucket(q, site, %Query{interval: "hour"}) do
    from(
      e in q,
      group_by: fragment("toStartOfHour(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      order_by: fragment("toStartOfHour(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      select_merge: %{
        date: fragment("toStartOfHour(toTimeZone(?, ?))", e.timestamp, ^site.timezone)
      }
    )
  end

  defp select_bucket(q, _site, %Query{interval: "minute", period: "30m"}) do
    from(
      e in q,
      group_by: fragment("dateDiff('minute', now(), ?)", e.timestamp),
      order_by: fragment("dateDiff('minute', now(), ?)", e.timestamp),
      select_merge: %{
        date: fragment("dateDiff('minute', now(), ?)", e.timestamp)
      }
    )
  end

  defp select_bucket(q, site, %Query{interval: "minute"}) do
    from(
      e in q,
      group_by: fragment("toStartOfMinute(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      order_by: fragment("toStartOfMinute(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      select_merge: %{
        date: fragment("toStartOfMinute(toTimeZone(?, ?))", e.timestamp, ^site.timezone)
      }
    )
  end

  defp date_or_weekstart(date, query) do
    weekstart = Timex.beginning_of_week(date)

    if Enum.member?(query.date_range, weekstart) do
      weekstart
    else
      date
    end
  end

  defp empty_row(date, metrics) do
    Enum.reduce(metrics, %{date: date}, fn metric, row ->
      case metric do
        :pageviews -> Map.merge(row, %{pageviews: 0})
        :events -> Map.merge(row, %{events: 0})
        :visitors -> Map.merge(row, %{visitors: 0})
        :visits -> Map.merge(row, %{visits: 0})
        :views_per_visit -> Map.merge(row, %{views_per_visit: 0.0})
        :conversion_rate -> Map.merge(row, %{conversion_rate: 0.0})
        :bounce_rate -> Map.merge(row, %{bounce_rate: nil})
        :visit_duration -> Map.merge(row, %{visit_duration: nil})
        :average_revenue -> Map.merge(row, %{average_revenue: nil})
        :total_revenue -> Map.merge(row, %{total_revenue: nil})
      end
    end)
  end

  on_full_build do
    defp cast_revenue_metrics_to_money(results, revenue_goals) do
      Plausible.Stats.Goal.Revenue.cast_revenue_metrics_to_money(results, revenue_goals)
    end
  else
    defp cast_revenue_metrics_to_money(results, _revenue_goals), do: results
  end

  defp maybe_add_timeseries_conversion_rate(q, site, query, metrics) do
    if :conversion_rate in metrics do
      totals_query = query |> Query.remove_event_filters([:goal, :props])

      totals_timeseries_q =
        from(e in base_event_query(site, totals_query),
          select: ^select_event_metrics([:visitors])
        )
        |> select_bucket(site, query)

      from(e in subquery(q),
        left_join: c in subquery(totals_timeseries_q),
        on: e.date == c.date,
        select_merge: %{
          total_visitors: c.visitors,
          conversion_rate:
            fragment(
              "if(? > 0, round(? / ? * 100, 1), 0)",
              c.visitors,
              e.visitors,
              c.visitors
            )
        }
      )
    else
      q
    end
  end
end
