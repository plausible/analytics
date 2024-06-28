defmodule Plausible.Stats.SQL.QueryBuilder do
  @moduledoc false

  use Plausible
  use Plausible.Stats.SQL.Fragments

  import Ecto.Query
  import Plausible.Stats.Imported
  import Plausible.Stats.Util

  alias Plausible.Stats.{Base, Filters, Query, QueryOptimizer, TableDecider, SQL}
  alias Plausible.Stats.SQL.Expression

  require Plausible.Stats.SQL.Expression

  def build(query, site) do
    {event_query, sessions_query} = QueryOptimizer.split(query)

    event_q = build_events_query(site, event_query)
    sessions_q = build_sessions_query(site, sessions_query)

    join_query_results(
      {event_q, event_query},
      {sessions_q, sessions_query}
    )
  end

  defp build_events_query(_site, %Query{metrics: []}), do: nil

  defp build_events_query(site, events_query) do
    q =
      from(
        e in "events_v2",
        where: ^SQL.WhereBuilder.build(:events, site, events_query),
        select: ^Base.select_event_metrics(events_query.metrics)
      )

    on_ee do
      q = Plausible.Stats.Sampling.add_query_hint(q, events_query)
    end

    q
    |> join_sessions_if_needed(site, events_query)
    |> build_group_by(events_query)
    |> merge_imported(site, events_query, events_query.metrics)
    |> maybe_add_global_conversion_rate(site, events_query)
    |> maybe_add_group_conversion_rate(site, events_query)
    |> Base.add_percentage_metric(site, events_query, events_query.metrics)
  end

  defp join_sessions_if_needed(q, site, query) do
    if TableDecider.events_join_sessions?(query) do
      sessions_q =
        from(
          s in Base.query_sessions(site, query),
          select: %{session_id: s.session_id},
          where: s.sign == 1,
          group_by: s.session_id
        )

      from(
        e in q,
        join: sq in subquery(sessions_q),
        on: e.session_id == sq.session_id
      )
    else
      q
    end
  end

  defp build_sessions_query(_site, %Query{metrics: []}), do: nil

  defp build_sessions_query(site, sessions_query) do
    q =
      from(
        e in "sessions_v2",
        where: ^SQL.WhereBuilder.build(:sessions, site, sessions_query),
        select: ^Base.select_session_metrics(sessions_query.metrics, sessions_query)
      )

    on_ee do
      q = Plausible.Stats.Sampling.add_query_hint(q, sessions_query)
    end

    q
    |> join_events_if_needed(site, sessions_query)
    |> build_group_by(sessions_query)
    |> merge_imported(site, sessions_query, sessions_query.metrics)
    |> maybe_add_global_conversion_rate(site, sessions_query)
    |> maybe_add_group_conversion_rate(site, sessions_query)
    |> Base.add_percentage_metric(site, sessions_query, sessions_query.metrics)
  end

  def join_events_if_needed(q, site, query) do
    if Query.has_event_filters?(query) do
      events_q =
        from(e in "events_v2",
          where: ^SQL.WhereBuilder.build(:events, site, query),
          select: %{
            session_id: fragment("DISTINCT ?", e.session_id),
            _sample_factor: fragment("_sample_factor")
          }
        )

      on_ee do
        events_q = Plausible.Stats.Sampling.add_query_hint(events_q, query)
      end

      from(s in q,
        join: e in subquery(events_q),
        on: s.session_id == e.session_id
      )
    else
      q
    end
  end

  defp build_group_by(q, query) do
    Enum.reduce(query.dimensions, q, &dimension_group_by(&2, query, &1))
  end

  defp dimension_group_by(q, query, "event:goal" = dimension) do
    {events, page_regexes} = Filters.Utils.split_goals_query_expressions(query.preloaded_goals)

    from(e in q,
      array_join: goal in Expression.event_goal_join(events, page_regexes),
      select_merge: %{
        ^shortname(query, dimension) => fragment("?", goal)
      },
      group_by: goal,
      where: goal != 0 and (e.name == "pageview" or goal < 0)
    )
  end

  defp dimension_group_by(q, query, dimension) do
    key = shortname(query, dimension)

    q
    |> select_merge(^Expression.dimension(key, dimension, query))
    |> group_by([], selected_as(^key))
  end

  defp build_order_by(q, query) do
    Enum.reduce(query.order_by || [], q, &build_order_by(&2, query, &1))
  end

  def build_order_by(q, query, {metric_or_dimension, order_direction}) do
    order_by(
      q,
      [t],
      {
        ^order_direction,
        selected_as(^shortname(query, metric_or_dimension))
      }
    )
  end

  defmacrop select_join_fields(q, query, list, table_name) do
    quote do
      Enum.reduce(unquote(list), unquote(q), fn metric_or_dimension, q ->
        key = shortname(unquote(query), metric_or_dimension)

        select_merge_as(
          q,
          [e, s],
          %{
            ^key => field(unquote(table_name), ^key)
          }
        )
      end)
    end
  end

  # Adds conversion_rate metric to query, calculated as
  # X / Y where Y is the same breakdown value without goal or props
  # filters.
  def maybe_add_global_conversion_rate(q, site, query) do
    if :conversion_rate in query.metrics do
      total_query =
        query
        |> Query.remove_filters(["event:goal", "event:props"])
        |> Query.set_dimensions([])

      q
      |> select_merge(
        ^%{
          total_visitors: Base.total_visitors_subquery(site, total_query, query.include_imported)
        }
      )
      |> select_merge_as([e], %{
        conversion_rate:
          fragment(
            "if(? > 0, round(? / ? * 100, 1), 0)",
            selected_as(:__total_visitors),
            selected_as(:visitors),
            selected_as(:__total_visitors)
          )
      })
    else
      q
    end
  end

  # This function injects a group_conversion_rate metric into
  # a dimensional query. It is calculated as X / Y, where:
  #
  #   * X is the number of conversions for a set of dimensions
  #     result (conversion = number of visitors who
  #     completed the filtered goal with the filtered
  #     custom properties).
  #
  #  * Y is the number of all visitors for this set of dimensions
  #    result without the `event:goal` and `event:props:*`
  #    filters.
  def maybe_add_group_conversion_rate(q, site, query) do
    if :group_conversion_rate in query.metrics do
      group_totals_query =
        query
        |> Query.remove_filters(["event:goal", "event:props"])
        |> Query.set_metrics([:visitors])
        |> Query.set_order_by([])

      from(e in subquery(q),
        left_join: c in subquery(build(group_totals_query, site)),
        on: ^build_group_by_join(query)
      )
      |> select_merge_as([e, c], %{
        total_visitors: c.visitors,
        group_conversion_rate:
          fragment(
            "if(? > 0, round(? / ? * 100, 1), 0)",
            c.visitors,
            e.visitors,
            c.visitors
          )
      })
      |> select_join_fields(query, query.dimensions, e)
      |> select_join_fields(query, List.delete(query.metrics, :group_conversion_rate), e)
    else
      q
    end
  end

  defp join_query_results({nil, _}, {nil, _}), do: nil

  defp join_query_results({events_q, events_query}, {nil, _}),
    do: events_q |> build_order_by(events_query)

  defp join_query_results({nil, events_query}, {sessions_q, _}),
    do: sessions_q |> build_order_by(events_query)

  defp join_query_results({events_q, events_query}, {sessions_q, sessions_query}) do
    join(subquery(events_q), :left, [e], s in subquery(sessions_q),
      on: ^build_group_by_join(events_query)
    )
    |> select_join_fields(events_query, events_query.dimensions, e)
    |> select_join_fields(events_query, events_query.metrics, e)
    |> select_join_fields(sessions_query, List.delete(sessions_query.metrics, :sample_percent), s)
    |> build_order_by(events_query)
  end

  def build_group_by_join(%Query{dimensions: []}), do: true

  def build_group_by_join(query) do
    query.dimensions
    |> Enum.map(fn dim ->
      dynamic([e, s], field(e, ^shortname(query, dim)) == field(s, ^shortname(query, dim)))
    end)
    |> Enum.reduce(fn condition, acc -> dynamic([], ^acc and ^condition) end)
  end
end
