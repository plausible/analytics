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

  def filter_converted_sessions(db_query, site, query) do
    if Query.has_event_filters?(query) do
      converted_sessions =
        from(e in query_events(site, query),
          select: %{
            session_id: fragment("DISTINCT ?", e.session_id),
            _sample_factor: fragment("_sample_factor")
          }
        )

      from(s in db_query,
        join: cs in subquery(converted_sessions),
        on: s.session_id == cs.session_id
      )
    else
      db_query
    end
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

  defp total_visitors(site, query) do
    base_event_query(site, query)
    |> select([e],
      total_visitors: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", e.user_id)
    )
  end

  # `total_visitors_subquery` returns a subquery which selects `total_visitors` -
  # the number used as the denominator in the calculation of `conversion_rate` and
  # `percentage` metrics.

  # Usually, when calculating the totals, a new query is passed into this function,
  # where certain filters (e.g. goal, props) are removed. That might make the query
  # able to include imported data. However, we always want to include imported data
  # only if it's included in the base query - otherwise the total will be based on
  # a different data set, making the metric inaccurate. This is why we're using an
  # explicit `include_imported` argument here.
  def total_visitors_subquery(site, query, include_imported)

  def total_visitors_subquery(site, query, true = _include_imported) do
    dynamic(
      [e],
      selected_as(
        subquery(total_visitors(site, query)) +
          subquery(Plausible.Stats.Imported.total_imported_visitors(site, query)),
        :__total_visitors
      )
    )
  end

  def total_visitors_subquery(site, query, false = _include_imported) do
    dynamic([e], selected_as(subquery(total_visitors(site, query)), :__total_visitors))
  end

  def add_percentage_metric(q, site, query, metrics) do
    if :percentage in metrics do
      total_query = Query.set_dimensions(query, [])

      q
      |> select_merge(
        ^%{__total_visitors: total_visitors_subquery(site, total_query, query.include_imported)}
      )
      |> select_merge(%{
        percentage:
          selected_as(
            fragment(
              "if(? > 0, round(? / ? * 100, 1), null)",
              selected_as(:__total_visitors),
              selected_as(:visitors),
              selected_as(:__total_visitors)
            ),
            :percentage
          )
      })
    else
      q
    end
  end

  # Adds conversion_rate metric to query, calculated as
  # X / Y where Y is the same breakdown value without goal or props
  # filters.
  def maybe_add_conversion_rate(q, site, query, metrics) do
    if :conversion_rate in metrics do
      total_query =
        query
        |> Query.remove_filters(["event:goal", "event:props"])
        |> Query.set_dimensions([])

      # :TRICKY: Subquery is used due to event:goal breakdown above doing an UNION ALL
      subquery(q)
      |> select_merge(
        ^%{total_visitors: total_visitors_subquery(site, total_query, query.include_imported)}
      )
      |> select_merge([e], %{
        conversion_rate:
          selected_as(
            fragment(
              "if(? > 0, round(? / ? * 100, 1), 0)",
              selected_as(:__total_visitors),
              e.visitors,
              selected_as(:__total_visitors)
            ),
            :conversion_rate
          )
      })
    else
      q
    end
  end
end
