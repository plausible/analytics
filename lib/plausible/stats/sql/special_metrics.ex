defmodule Plausible.Stats.SQL.SpecialMetrics do
  @moduledoc """
  This module defines how special metrics like `conversion_rate` and
  `percentage` are calculated.
  """

  use Plausible.Stats.SQL.Fragments

  alias Plausible.Stats.{Base, Query, SQL, Filters}

  import Ecto.Query
  import Plausible.Stats.Util

  @special_metrics [
    :percentage,
    :conversion_rate,
    :group_conversion_rate,
    :scroll_depth,
    :exit_rate
  ]

  def add(q, site, query) do
    Enum.reduce(@special_metrics, q, fn special_metric, q ->
      if special_metric in query.metrics do
        add_special_metric(q, special_metric, site, query)
      else
        q
      end
    end)
  end

  defp add_special_metric(q, :percentage, site, query) do
    total_query =
      query
      |> remove_filters_ignored_in_totals_query()
      |> Query.set(
        dimensions: [],
        include_imported: query.include_imported,
        pagination: nil
      )

    q
    |> select_merge_as([], total_visitors_subquery(site, total_query, query.include_imported))
    |> select_merge_as([], %{
      percentage:
        fragment(
          "if(? > 0, round(? / ? * 100, 1), null)",
          selected_as(:total_visitors),
          selected_as(:visitors),
          selected_as(:total_visitors)
        )
    })
  end

  # Adds conversion_rate metric to query, calculated as
  # X / Y where Y is the same breakdown value without goal or props
  # filters.
  defp add_special_metric(q, :conversion_rate, site, query) do
    total_query =
      query
      |> Query.remove_top_level_filters(["event:goal", "event:props"])
      |> remove_filters_ignored_in_totals_query()
      |> Query.set(
        dimensions: [],
        include_imported: query.include_imported,
        preloaded_goals: Map.put(query.preloaded_goals, :matching_toplevel_filters, []),
        pagination: nil
      )

    q
    |> select_merge_as(
      [],
      total_visitors_subquery(site, total_query, query.include_imported)
    )
    |> select_merge_as([e], %{
      conversion_rate:
        fragment(
          "if(? > 0, round(? / ? * 100, 2), 0)",
          selected_as(:total_visitors),
          selected_as(:visitors),
          selected_as(:total_visitors)
        )
    })
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
  defp add_special_metric(q, :group_conversion_rate, site, query) do
    group_totals_query =
      query
      |> Query.remove_top_level_filters(["event:goal", "event:props"])
      |> remove_filters_ignored_in_totals_query()
      |> Query.set(
        metrics: [:visitors],
        order_by: [],
        include_imported: query.include_imported,
        preloaded_goals: Map.put(query.preloaded_goals, :matching_toplevel_filters, []),
        pagination: nil
      )

    from(e in subquery(q),
      left_join: c in subquery(SQL.QueryBuilder.build(group_totals_query, site)),
      on: ^SQL.QueryBuilder.build_group_by_join(query)
    )
    |> select_merge_as([e, c], %{
      total_visitors: c.visitors,
      group_conversion_rate:
        fragment(
          "if(? > 0, round(? / ? * 100, 2), 0)",
          c.visitors,
          e.visitors,
          c.visitors
        )
    })
    |> select_join_fields(query, query.dimensions, e)
    |> select_join_fields(query, List.delete(query.metrics, :group_conversion_rate), e)
  end

  defp add_special_metric(q, :scroll_depth, _site, query) do
    max_per_session_q =
      Base.base_event_query(query)
      |> where([e], e.name == "engagement" and e.scroll_depth <= 100)
      |> select([e], %{
        session_id: e.session_id,
        max_scroll_depth: max(e.scroll_depth)
      })
      |> SQL.QueryBuilder.build_group_by(:events, query)
      |> group_by([e], e.session_id)

    dim_shortnames = Enum.map(query.dimensions, fn dim -> shortname(query, dim) end)

    dim_select =
      dim_shortnames
      |> Enum.map(fn dim -> {dim, dynamic([p], field(p, ^dim))} end)
      |> Map.new()

    dim_group_by =
      dim_shortnames
      |> Enum.map(fn dim -> dynamic([p], field(p, ^dim)) end)

    total_scroll_depth_q =
      subquery(max_per_session_q)
      |> select([], %{})
      |> select_merge_as([p], %{
        # Note: No need to upscale sample size here since it would end up cancelling out due to the result being an average
        total_scroll_depth: fragment("sum(?)", p.max_scroll_depth),
        total_scroll_depth_visits: fragment("uniq(?)", p.session_id)
      })
      |> select_merge(^dim_select)
      |> group_by(^dim_group_by)

    join_on_dim_condition =
      if dim_shortnames == [] do
        true
      else
        dim_shortnames
        |> Enum.map(fn dim -> dynamic([_e, ..., s], selected_as(^dim) == field(s, ^dim)) end)
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        |> Enum.reduce(fn condition, acc -> dynamic([], ^acc and ^condition) end)
      end

    joined_q =
      join(q, :left, [e], s in subquery(total_scroll_depth_q), on: ^join_on_dim_condition)

    if query.include_imported do
      joined_q
      |> select_merge_as([..., s], %{
        scroll_depth:
          fragment(
            """
            if(? + ? > 0, toInt8(round((? + ?) / (? + ?))), NULL)
            """,
            s.total_scroll_depth_visits,
            selected_as(:__imported_total_scroll_depth_visits),
            s.total_scroll_depth,
            selected_as(:__imported_total_scroll_depth),
            s.total_scroll_depth_visits,
            selected_as(:__imported_total_scroll_depth_visits)
          )
      })
    else
      joined_q
      |> select_merge_as([..., s], %{
        scroll_depth:
          fragment(
            "if(any(?) > 0, toUInt8(round(any(?) / any(?))), NULL)",
            s.total_scroll_depth_visits,
            s.total_scroll_depth,
            s.total_scroll_depth_visits
          )
      })
    end
  end

  # Selects exit_rate into the query, calculated as X / Y, where X is the
  # total number of exits from a page (i.e. the number of sessions with a
  # specific exit page), and Y is the total pageviews on that page.
  defp add_special_metric(q, :exit_rate, site, query) do
    total_pageviews_query =
      query
      |> Query.remove_top_level_filters(["visit:exit_page"])
      |> remove_filters_ignored_in_totals_query()
      |> Query.set(
        pagination: nil,
        order_by: [],
        metrics: [:pageviews],
        include_imported: query.include_imported,
        dimensions: ["event:page"]
      )

    joined_q =
      q
      |> join(:left, [], p in subquery(SQL.QueryBuilder.build(total_pageviews_query, site)),
        on:
          selected_as(^shortname(query, "visit:exit_page")) ==
            field(p, ^shortname(total_pageviews_query, "event:page"))
      )

    if query.include_imported do
      joined_q
      |> select_merge_as([..., p], %{
        exit_rate:
          fragment(
            "if(? > 0, round(? / ? * 100, 1), NULL)",
            p.pageviews,
            selected_as(:__internal_visits),
            p.pageviews
          )
      })
    else
      joined_q
      |> select_merge_as([..., p], %{
        exit_rate:
          fragment(
            "if(? > 0, round(? / ? * 100, 1), NULL)",
            fragment("any(?)", p.pageviews),
            selected_as(:__internal_visits),
            fragment("any(?)", p.pageviews)
          )
      })
    end
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
  defp total_visitors_subquery(site, query, include_imported)

  defp total_visitors_subquery(site, query, true = _include_imported) do
    wrap_alias([], %{
      total_visitors:
        subquery(total_visitors(query)) +
          subquery(Plausible.Stats.Imported.total_imported_visitors(site, query))
    })
  end

  defp total_visitors_subquery(_site, query, false = _include_imported) do
    wrap_alias([], %{
      total_visitors: subquery(total_visitors(query))
    })
  end

  defp remove_filters_ignored_in_totals_query(query) do
    totals_query_filters =
      Filters.transform_filters(query.filters, fn
        [:ignore_in_totals_query, _] -> []
        filter -> [filter]
      end)

    Query.set(query, filters: totals_query_filters)
  end

  defp total_visitors(query) do
    Base.base_event_query(query)
    |> select([e],
      total_visitors: scale_sample(fragment("uniq(?)", e.user_id))
    )
  end
end
