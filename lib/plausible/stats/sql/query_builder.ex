defmodule Plausible.Stats.SQL.QueryBuilder do
  @moduledoc false

  use Plausible
  use Plausible.Stats.SQL.Fragments

  import Ecto.Query
  import Plausible.Stats.Imported
  import Plausible.Stats.Util

  alias Plausible.Stats.{Query, QueryOptimizer, TableDecider, SQL}
  alias Plausible.Stats.SQL.Expression
  alias Plausible.Stats.Legacy.TimeOnPage

  require Plausible.Stats.SQL.Expression

  def build(query, site) do
    {event_query, sessions_query} = QueryOptimizer.split(query)

    event_q = build_events_query(site, event_query)
    sessions_q = build_sessions_query(site, sessions_query)

    join_query_results(
      {event_q, event_query},
      {sessions_q, sessions_query}
    )
    |> paginate(query.pagination)
    |> select_total_rows(query.include.total_rows)
  end

  def build_order_by(q, query) do
    Enum.reduce(query.order_by || [], q, &build_order_by(&2, query, &1))
  end

  defp build_events_query(_site, %Query{metrics: []}), do: nil

  defp build_events_query(site, events_query) do
    q =
      from(
        e in "events_v2",
        where: ^SQL.WhereBuilder.build(:events, events_query),
        select: ^select_event_metrics(events_query)
      )

    on_ee do
      q = Plausible.Stats.Sampling.add_query_hint(q, events_query)
    end

    q
    |> join_sessions_if_needed(events_query)
    |> build_group_by(:events, events_query)
    |> merge_imported(site, events_query)
    |> SQL.SpecialMetrics.add(site, events_query)
    |> TimeOnPage.merge_legacy_time_on_page(events_query)
  end

  defp join_sessions_if_needed(q, query) do
    if TableDecider.events_join_sessions?(query) do
      sessions_q =
        from(
          s in "sessions_v2",
          where: ^SQL.WhereBuilder.build(:sessions, query),
          where: s.sign == 1,
          select: %{session_id: s.session_id},
          group_by: s.session_id
        )

      on_ee do
        sessions_q = Plausible.Stats.Sampling.add_query_hint(sessions_q, query)
      end

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
        where: ^SQL.WhereBuilder.build(:sessions, sessions_query),
        select: ^select_session_metrics(sessions_query)
      )

    on_ee do
      q = Plausible.Stats.Sampling.add_query_hint(q, sessions_query)
    end

    q
    |> join_events_if_needed(sessions_query)
    |> build_group_by(:sessions, sessions_query)
    |> merge_imported(site, sessions_query)
    |> SQL.SpecialMetrics.add(site, sessions_query)
  end

  def join_events_if_needed(q, query) do
    if TableDecider.sessions_join_events?(query) do
      events_q =
        from(e in "events_v2",
          where: ^SQL.WhereBuilder.build(:events, query),
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

  defp select_event_metrics(query) do
    query.metrics
    |> Enum.map(&SQL.Expression.event_metric(&1, query))
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp select_session_metrics(query) do
    query.metrics
    |> Enum.map(&SQL.Expression.session_metric(&1, query))
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  def build_group_by(q, table, query) do
    Enum.reduce(query.dimensions, q, &dimension_group_by(&2, table, query, &1))
  end

  defp dimension_group_by(q, :events, query, "event:goal" = dimension) do
    goal_join_data = Plausible.Stats.Goals.goal_join_data(query)

    from(e in q,
      join: goal in Expression.event_goal_join(goal_join_data),
      hints: "ARRAY",
      on: true,
      select_merge: %{
        ^shortname(query, dimension) => fragment("?", goal)
      },
      group_by: goal
    )
  end

  defp dimension_group_by(q, table, query, dimension) do
    key = shortname(query, dimension)

    q
    |> Expression.select_dimension(key, dimension, table, query)
    |> group_by([], selected_as(^key))
  end

  defp build_order_by(q, query, {metric_or_dimension, order_direction}) do
    order_by(
      q,
      [t],
      {
        ^order_direction,
        selected_as(^shortname(query, metric_or_dimension))
      }
    )
  end

  defp join_query_results({nil, _}, {nil, _}), do: nil

  defp join_query_results({events_q, events_query}, {nil, _}),
    do: events_q |> build_order_by(events_query)

  defp join_query_results({nil, events_query}, {sessions_q, _}),
    do: sessions_q |> build_order_by(events_query)

  defp join_query_results({events_q, events_query}, {sessions_q, sessions_query}) do
    {join_type, events_q_fields, sessions_q_fields} =
      TableDecider.join_options(events_query, sessions_query)

    join(subquery(events_q), join_type, [e], s in subquery(sessions_q),
      on: ^build_group_by_join(events_query)
    )
    |> select_join_fields(events_query, events_q_fields, e)
    |> select_join_fields(sessions_query, sessions_q_fields, s)
    |> build_order_by(events_query)
  end

  # NOTE: Old queries do their own pagination
  defp paginate(q, nil = _pagination), do: q

  defp paginate(q, pagination) do
    q
    |> limit(^pagination.limit)
    |> offset(^pagination.offset)
  end

  defp select_total_rows(q, false = _include_total_rows), do: q

  defp select_total_rows(q, true = _include_total_rows) do
    q
    |> select_merge([], %{total_rows: fragment("count() over ()")})
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
