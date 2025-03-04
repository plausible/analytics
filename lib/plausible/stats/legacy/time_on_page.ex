defmodule Plausible.Stats.Legacy.TimeOnPage do
  @moduledoc """
  Calculation methods for `legacy` time_on_page metric. `Legacy` calculation methods
  are used when site does not have engagement data for the requested dates.

  Query `include.combined_time_on_page_cutoff` is used to determine what time range
  to use for the legacy time_on_page calculations.

  Legacy metric is not exposed in the public API.
  """

  use Plausible.ClickhouseRepo
  use Plausible.Stats.SQL.Fragments

  import Ecto.Query
  import Plausible.Stats.Util

  alias Plausible.Stats.{Base, Filters, Query, SQL}

  def can_merge_legacy_time_on_page?(query) do
    :time_on_page in query.metrics and query.dimensions in [[], ["event:page"]]
  end

  def merge_legacy_time_on_page(q, query) do
    # :TODO: this will likely not work if legacy data is requested with incompatible dimensions.
    if :time_on_page in query.metrics and query.time_on_page_combined_data.include_legacy_metric do
      q |> merge_legacy_time_on_page(query, query.dimensions)
    else
      q
    end
  end

  defp merge_legacy_time_on_page(q, query, []) do
    from(
      e in subquery(q),
      inner_join: t in subquery(aggregate_time_on_page_q(query)),
      on: true
    )
    |> select_metrics_and_dimensions(query)
  end

  defp merge_legacy_time_on_page(q, query, ["event:page"]) do
    from(
      e in subquery(q),
      left_join: t in subquery(breakdown_q(query)),
      on: e.dim0 == t.pathname
    )
    |> select_metrics_and_dimensions(query)
  end

  defp merge_legacy_time_on_page(q, _query, _dimensions) do
    q
  end

  defp select_metrics_and_dimensions(q, query) do
    q
    |> select_join_fields(query, List.delete(query.metrics, :time_on_page), e)
    |> select_join_fields(query, query.dimensions, e)
    |> select_merge_as([e, t], %{
      time_on_page:
        time_on_page(
          e.__internal_total_time_on_page + t.total_time_on_page,
          e.__internal_total_time_on_page_visits + t.transition_count
        )
    })
  end

  defp aggregate_time_on_page_q(query) do
    windowed_pages_q =
      from(e in Base.base_event_query(Query.remove_top_level_filters(query, ["event:page"])),
        where: e.name != "engagement",
        where: ^filter_by_cutoff(query),
        select: %{
          next_timestamp: over(fragment("leadInFrame(?)", e.timestamp), :event_horizon),
          next_pathname: over(fragment("leadInFrame(?)", e.pathname), :event_horizon),
          timestamp: e.timestamp,
          pathname: e.pathname,
          session_id: e.session_id
        },
        windows: [
          event_horizon: [
            partition_by: e.session_id,
            order_by: e.timestamp,
            frame: fragment("ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING")
          ]
        ]
      )

    event_page_filter = Filters.get_toplevel_filter(query, "event:page")

    timed_page_transitions_q =
      from e in Ecto.Query.subquery(windowed_pages_q),
        group_by: [e.pathname, e.next_pathname, e.session_id],
        where: ^SQL.WhereBuilder.build_condition(:pathname, event_page_filter),
        where: e.next_timestamp != 0,
        select: %{
          pathname: e.pathname,
          transition: e.next_pathname != e.pathname,
          duration: sum(e.next_timestamp - e.timestamp)
        }

    avg_time_per_page_transition_q =
      from e in Ecto.Query.subquery(timed_page_transitions_q),
        select: %{
          avg: fragment("sum(?)/countIf(?)", e.duration, e.transition),
          duration: fragment("sum(?)", e.duration),
          transition_count: fragment("countIf(?)", e.transition)
        },
        group_by: e.pathname

    from(
      e in subquery(avg_time_per_page_transition_q),
      select: %{
        time_on_page: fragment("avg(ifNotFinite(?,NULL))", e.avg),
        total_time_on_page: fragment("sum(?)", e.duration),
        transition_count: fragment("sum(?)", e.transition_count)
      }
    )
  end

  defp breakdown_q(query) do
    windowed_pages_q =
      from(
        e in Base.base_event_query(
          Query.remove_top_level_filters(query, ["event:page", "event:props"])
        ),
        where: e.name != "engagement",
        where: ^filter_by_cutoff(query),
        select: %{
          next_timestamp: over(fragment("leadInFrame(?)", e.timestamp), :event_horizon),
          next_pathname: over(fragment("leadInFrame(?)", e.pathname), :event_horizon),
          timestamp: e.timestamp,
          pathname: e.pathname,
          session_id: e.session_id
        },
        windows: [
          event_horizon: [
            partition_by: e.session_id,
            order_by: e.timestamp,
            frame: fragment("ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING")
          ]
        ]
      )

    timed_page_transitions_q =
      from(e in subquery(windowed_pages_q),
        group_by: [e.pathname, e.next_pathname, e.session_id],
        where: e.next_timestamp != 0,
        select: %{
          pathname: e.pathname,
          transition: e.next_pathname != e.pathname,
          duration: sum(e.next_timestamp - e.timestamp)
        }
      )

    no_select_timed_pages_q =
      from e in subquery(timed_page_transitions_q),
        group_by: e.pathname

    date_range = Query.date_range(query)

    if query.include_imported do
      # Imported page views have pre-calculated values
      imported_timed_pages_q =
        from(i in "imported_pages",
          group_by: i.page,
          where: i.site_id == ^query.site_id,
          where: i.date >= ^date_range.first and i.date <= ^date_range.last,
          select: %{
            page: i.page,
            time_on_page: sum(i.total_time_on_page),
            visits: sum(i.pageviews) - sum(i.exits)
          }
        )

      timed_pages_q =
        from e in no_select_timed_pages_q,
          select: %{
            page: e.pathname,
            time_on_page: fragment("sum(?)", e.duration),
            visits: fragment("countIf(?)", e.transition)
          }

      "timed_pages"
      |> with_cte("timed_pages", as: ^timed_pages_q)
      |> with_cte("imported_timed_pages", as: ^imported_timed_pages_q)
      |> join(:full, [t], i in "imported_timed_pages", on: t.page == i.page)
      |> select(
        [t, i],
        %{
          pathname: fragment("if(empty(?),?,?)", t.page, i.page, t.page),
          time_on_page: (t.time_on_page + i.time_on_page) / (t.visits + i.visits),
          total_time_on_page: t.time_on_page + i.time_on_page,
          transition_count: t.visits + i.visits
        }
      )
    else
      from(e in no_select_timed_pages_q,
        select: %{
          pathname: e.pathname,
          time_on_page: fragment("sum(?)/countIf(?)", e.duration, e.transition),
          total_time_on_page: fragment("sum(?)", e.duration),
          transition_count: fragment("countIf(?)", e.transition)
        }
      )
    end
  end

  defp filter_by_cutoff(query) do
    case query.time_on_page_combined_data do
      %{include_legacy_metric: true, include_new_metric: true, cutoff: cutoff} ->
        dynamic([e], e.timestamp < ^cutoff)

      _ ->
        true
    end
  end
end
