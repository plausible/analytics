defmodule Plausible.Stats.Base do
  use Plausible.ClickhouseRepo
  use Plausible
  use Plausible.Stats.SQL.Fragments

  alias Plausible.Stats.{Query, TableDecider, SQL}
  alias Plausible.Timezones
  import Ecto.Query

  def base_event_query(site, query) do
    events_q = query_events(site, query)

    if TableDecider.events_join_sessions?(query) do
      sessions_q =
        from(
          s in query_sessions(site, query),
          select: %{session_id: s.session_id},
          where: s.sign == 1,
          group_by: s.session_id
        )

      from(
        e in events_q,
        join: sq in subquery(sessions_q),
        on: e.session_id == sq.session_id
      )
    else
      events_q
    end
  end

  def query_events(site, query) do
    q = from(e in "events_v2", where: ^SQL.WhereBuilder.build(:events, site, query))

    on_ee do
      q = Plausible.Stats.Sampling.add_query_hint(q, query)
    end

    q
  end

  def query_sessions(site, query) do
    q = from(s in "sessions_v2", where: ^SQL.WhereBuilder.build(:sessions, site, query))

    on_ee do
      q = Plausible.Stats.Sampling.add_query_hint(q, query)
    end

    q
  end

  def select_event_metrics(metrics) do
    metrics
    |> Enum.map(&SQL.Expression.event_metric/1)
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  def select_session_metrics(metrics, query) do
    metrics
    |> Enum.map(&SQL.Expression.session_metric(&1, query))
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp beginning_of_time(candidate, native_stats_start_at) do
    if Timex.after?(native_stats_start_at, candidate) do
      native_stats_start_at
    else
      candidate
    end
  end

  def utc_boundaries(%Query{period: "realtime", now: now}, site) do
    last_datetime =
      now
      |> Timex.shift(seconds: 5)
      |> beginning_of_time(site.native_stats_start_at)
      |> NaiveDateTime.truncate(:second)

    first_datetime =
      now |> Timex.shift(minutes: -5) |> NaiveDateTime.truncate(:second)

    {first_datetime, last_datetime}
  end

  def utc_boundaries(%Query{period: "30m", now: now}, site) do
    last_datetime =
      now
      |> Timex.shift(seconds: 5)
      |> beginning_of_time(site.native_stats_start_at)
      |> NaiveDateTime.truncate(:second)

    first_datetime =
      now |> Timex.shift(minutes: -30) |> NaiveDateTime.truncate(:second)

    {first_datetime, last_datetime}
  end

  def utc_boundaries(%Query{date_range: date_range}, site) do
    {:ok, first} = NaiveDateTime.new(date_range.first, ~T[00:00:00])

    first_datetime =
      first
      |> Timezones.to_utc_datetime(site.timezone)
      |> beginning_of_time(site.native_stats_start_at)

    {:ok, last} = NaiveDateTime.new(date_range.last |> Timex.shift(days: 1), ~T[00:00:00])

    last_datetime = Timezones.to_utc_datetime(last, site.timezone)

    {first_datetime, last_datetime}
  end

  def page_regex(expr) do
    escaped =
      expr
      |> Regex.escape()
      |> String.replace("\\|", "|")
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", ".*")

    "^#{escaped}$"
  end
end
