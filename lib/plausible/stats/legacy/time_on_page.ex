defmodule Plausible.Stats.Legacy.TimeOnPage do
  @moduledoc """
  Calculation methods for legacy time_on_page metric. Note the metric
  has its own limitations and quirks.

  Closely coupled with Plausible.Stats.QueryRunner.
  """

  use Plausible.ClickhouseRepo
  import Ecto.Query

  alias Plausible.Stats.{Base, Filters, Query, SQL, Util}

  def calculate(site, query, ch_results) do
    case {:time_on_page in query.metrics, query.dimensions} do
      {true, []} ->
        aggregate_time_on_page(site, query)

      {true, ["event:page"]} ->
        pages =
          Enum.map(ch_results, fn entry -> Map.get(entry, Util.shortname(query, "event:page")) end)

        breakdown_time_on_page(site, query, pages)

      _ ->
        %{}
    end
  end

  defp aggregate_time_on_page(site, query) do
    windowed_pages_q =
      from e in Base.base_event_query(site, Query.remove_top_level_filters(query, ["event:page"])),
        where: e.name != "engagement",
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
        select: %{avg: fragment("sum(?)/countIf(?)", e.duration, e.transition)},
        group_by: e.pathname

    time_on_page_q =
      from e in Ecto.Query.subquery(avg_time_per_page_transition_q),
        select: fragment("avg(ifNotFinite(?,NULL))", e.avg)

    %{[] => ClickhouseRepo.one(time_on_page_q, query: query)}
  end

  defp breakdown_time_on_page(_site, _query, []) do
    %{}
  end

  defp breakdown_time_on_page(site, query, pages) do
    import Ecto.Query

    windowed_pages_q =
      from e in Base.base_event_query(
             site,
             Query.remove_top_level_filters(query, ["event:page", "event:props"])
           ),
           where: e.name != "engagement",
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

    timed_page_transitions_q =
      from e in subquery(windowed_pages_q),
        group_by: [e.pathname, e.next_pathname, e.session_id],
        where: e.pathname in ^pages,
        where: e.next_timestamp != 0,
        select: %{
          pathname: e.pathname,
          transition: e.next_pathname != e.pathname,
          duration: sum(e.next_timestamp - e.timestamp)
        }

    no_select_timed_pages_q =
      from e in subquery(timed_page_transitions_q),
        group_by: e.pathname

    date_range = Query.date_range(query)

    timed_pages_q =
      if query.include_imported do
        # Imported page views have pre-calculated values
        imported_timed_pages_q =
          from i in "imported_pages",
            group_by: i.page,
            where: i.site_id == ^site.id,
            where: i.date >= ^date_range.first and i.date <= ^date_range.last,
            where: i.page in ^pages,
            select: %{
              page: i.page,
              time_on_page: sum(i.total_time_on_page),
              visits: sum(i.pageviews) - sum(i.exits)
            }

        timed_pages_q =
          from e in no_select_timed_pages_q,
            select: %{
              page: e.pathname,
              time_on_page: sum(e.duration),
              visits: fragment("countIf(?)", e.transition)
            }

        "timed_pages"
        |> with_cte("timed_pages", as: ^timed_pages_q)
        |> with_cte("imported_timed_pages", as: ^imported_timed_pages_q)
        |> join(:full, [t], i in "imported_timed_pages", on: t.page == i.page)
        |> select(
          [t, i],
          {
            fragment("if(empty(?),?,?)", t.page, i.page, t.page),
            (t.time_on_page + i.time_on_page) / (t.visits + i.visits)
          }
        )
      else
        from e in no_select_timed_pages_q,
          select: {e.pathname, fragment("sum(?)/countIf(?)", e.duration, e.transition)}
      end

    timed_pages_q
    |> Plausible.ClickhouseRepo.all(query: query)
    |> Map.new(fn {path, value} -> {[path], value} end)
  end
end
