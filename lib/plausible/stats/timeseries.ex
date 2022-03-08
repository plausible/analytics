defmodule Plausible.Stats.Timeseries do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.Query
  import Plausible.Stats.Base
  use Plausible.Stats.Fragments

  @event_metrics [:visitors, :pageviews]
  @session_metrics [:visits, :bounce_rate, :visit_duration]
  def timeseries(site, query, metrics) do
    steps = buckets(query)

    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))

    [event_result, session_result] =
      Task.await_many(
        [
          Task.async(fn -> events_timeseries(site, query, event_metrics) end),
          Task.async(fn -> sessions_timeseries(site, query, session_metrics) end)
        ],
        10_000
      )

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
  end

  def buckets(%Query{interval: "month"} = query) do
    n_buckets = Timex.diff(query.date_range.last, query.date_range.first, :months)

    Enum.map(n_buckets..0, fn shift ->
      query.date_range.last
      |> Timex.beginning_of_month()
      |> Timex.shift(months: -shift)
    end)
  end

  def buckets(%Query{interval: "date"} = query) do
    Enum.into(query.date_range, [])
  end

  def buckets(%Query{interval: "hour"} = query) do
    Enum.map(0..23, fn step ->
      Timex.to_datetime(query.date_range.first)
      |> Timex.shift(hours: step)
      |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
    end)
  end

  def buckets(%Query{period: "30m", interval: "minute"}) do
    Enum.into(-30..-1, [])
  end

  def select_bucket(q, site, %Query{interval: "month"}) do
    from(
      e in q,
      group_by: fragment("toStartOfMonth(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      order_by: fragment("toStartOfMonth(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      select_merge: %{
        date: fragment("toStartOfMonth(toTimeZone(?, ?))", e.timestamp, ^site.timezone)
      }
    )
  end

  def select_bucket(q, site, %Query{interval: "date"}) do
    from(
      e in q,
      group_by: fragment("toDate(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      order_by: fragment("toDate(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      select_merge: %{
        date: fragment("toDate(toTimeZone(?, ?))", e.timestamp, ^site.timezone)
      }
    )
  end

  def select_bucket(q, site, %Query{interval: "hour"}) do
    from(
      e in q,
      group_by: fragment("toStartOfHour(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      order_by: fragment("toStartOfHour(toTimeZone(?, ?))", e.timestamp, ^site.timezone),
      select_merge: %{
        date: fragment("toStartOfHour(toTimeZone(?, ?))", e.timestamp, ^site.timezone)
      }
    )
  end

  def select_bucket(q, _site, %Query{interval: "minute"}) do
    from(
      e in q,
      group_by: fragment("dateDiff('minute', now(), ?)", e.timestamp),
      order_by: fragment("dateDiff('minute', now(), ?)", e.timestamp),
      select_merge: %{
        date: fragment("dateDiff('minute', now(), ?)", e.timestamp)
      }
    )
  end

  defp empty_row(date, metrics) do
    Enum.reduce(metrics, %{date: date}, fn metric, row ->
      case metric do
        :pageviews -> Map.merge(row, %{pageviews: 0})
        :visitors -> Map.merge(row, %{visitors: 0})
        :visits -> Map.merge(row, %{visits: 0})
        :bounce_rate -> Map.merge(row, %{bounce_rate: nil})
        :visit_duration -> Map.merge(row, %{:visit_duration => nil})
      end
    end)
  end
end
