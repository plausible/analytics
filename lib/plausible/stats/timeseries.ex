defmodule Plausible.Stats.Timeseries do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.Query
  import Plausible.Stats.{Base, Util}
  use Plausible.Stats.Fragments

  @typep metric :: :pageviews | :visitors | :visits | :bounce_rate | :visit_duration
  @typep value :: nil | integer() | float()
  @type results :: nonempty_list(%{required(:date) => Date.t(), required(metric()) => value()})

  @event_metrics [:visitors, :pageviews]
  @session_metrics [:visits, :bounce_rate, :visit_duration, :views_per_visit]
  def timeseries(site, query, metrics) do
    steps = buckets(query)

    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))

    [event_result, session_result] =
      Plausible.ClickhouseRepo.parallel_tasks([
        fn -> events_timeseries(site, query, event_metrics) end,
        fn -> sessions_timeseries(site, query, session_metrics) end
      ])

    Enum.map(steps, fn step ->
      empty_row(step, metrics)
      |> Map.merge(Enum.find(event_result, fn row -> row[:date] == step end) || %{})
      |> Map.merge(Enum.find(session_result, fn row -> row[:date] == step end) || %{})
    end)
  end

  defp events_timeseries(_, _, []), do: []

  defp events_timeseries(site, query, metrics) do
    from(e in base_event_query(site, query), select: %{})
    |> select_bucket(site, query)
    |> select_event_metrics(metrics)
    |> Plausible.Stats.Imported.merge_imported_timeseries(site, query, metrics)
    |> ClickhouseRepo.all()
  end

  defp sessions_timeseries(_, _, []), do: []

  defp sessions_timeseries(site, query, metrics) do
    query = Query.treat_page_filter_as_entry_page(query)

    from(e in query_sessions(site, query), select: %{})
    |> select_bucket(site, query)
    |> select_session_metrics(metrics)
    |> Plausible.Stats.Imported.merge_imported_timeseries(site, query, metrics)
    |> ClickhouseRepo.all()
    |> remove_internal_visits_metric(metrics)
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
      if query.date_range.first == query.date_range.last do
        @full_day_in_hours
      else
        Timex.diff(query.date_range.last, query.date_range.first, :hours)
      end

    Enum.map(0..n_buckets, fn step ->
      query.date_range.first
      |> Timex.to_datetime()
      |> Timex.shift(hours: step)
      |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
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
      |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
    end)
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
      group_by:
        fragment("toString(toStartOfHour(toTimeZone(?, ?)))", e.timestamp, ^site.timezone),
      order_by:
        fragment("toString(toStartOfHour(toTimeZone(?, ?)))", e.timestamp, ^site.timezone),
      select_merge: %{
        date: fragment("toString(toStartOfHour(toTimeZone(?, ?)))", e.timestamp, ^site.timezone)
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
      group_by:
        fragment("toString(toStartOfMinute(toTimeZone(?, ?)))", e.timestamp, ^site.timezone),
      order_by:
        fragment("toString(toStartOfMinute(toTimeZone(?, ?)))", e.timestamp, ^site.timezone),
      select_merge: %{
        date: fragment("toString(toStartOfMinute(toTimeZone(?, ?)))", e.timestamp, ^site.timezone)
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
        :visitors -> Map.merge(row, %{visitors: 0})
        :visits -> Map.merge(row, %{visits: 0})
        :views_per_visit -> Map.merge(row, %{views_per_visit: 0.0})
        :bounce_rate -> Map.merge(row, %{bounce_rate: nil})
        :visit_duration -> Map.merge(row, %{:visit_duration => nil})
      end
    end)
  end
end
