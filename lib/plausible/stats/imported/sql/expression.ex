defmodule Plausible.Stats.Imported.SQL.Expression do
  @moduledoc """
  This module is responsible for generating SQL/Ecto expressions
  for dimensions, filters and metrics used in import table queries
  """

  use Plausible.Stats.SQL.Fragments

  import Plausible.Stats.Util, only: [shortname: 2]
  import Ecto.Query

  alias Plausible.Stats.Query

  @no_ref "Direct / None"
  @not_set "(not set)"
  @none "(none)"

  def select_imported_metrics(
        %Ecto.Query{from: %Ecto.Query.FromExpr{source: {table, _}}} = q,
        metrics
      ) do
    select_clause =
      metrics
      |> Enum.map(&select_metric(&1, table))
      |> Enum.reduce(%{}, &Map.merge/2)

    q
    |> select_merge(q, ^select_clause)
    |> filter_pageviews(metrics, table)
  end

  defp filter_pageviews(q, metrics, table) do
    should_filter = :pageviews in metrics or :views_per_visit in metrics

    case {should_filter, table} do
      {_, "imported_custom_events"} -> q
      {true, _} -> q |> where([i], i.pageviews > 0)
      {false, _} -> q
    end
  end

  defp select_metric(:visitors, _table) do
    wrap_alias([i], %{visitors: sum(i.visitors)})
  end

  defp select_metric(:events, "imported_custom_events") do
    wrap_alias([i], %{events: sum(i.events)})
  end

  defp select_metric(:events, _table) do
    wrap_alias([i], %{events: sum(i.pageviews)})
  end

  defp select_metric(:visits, "imported_exit_pages") do
    wrap_alias([i], %{visits: sum(i.exits)})
  end

  defp select_metric(:visits, "imported_entry_pages") do
    wrap_alias([i], %{visits: sum(i.entrances)})
  end

  defp select_metric(:visits, _table) do
    wrap_alias([i], %{visits: sum(i.visits)})
  end

  defp select_metric(:pageviews, "imported_custom_events") do
    wrap_alias([i], %{pageviews: 0})
  end

  defp select_metric(:pageviews, _table) do
    wrap_alias([i], %{pageviews: sum(i.pageviews)})
  end

  defp select_metric(:bounce_rate, "imported_pages") do
    wrap_alias([i], %{bounces: 0, __internal_visits: 0})
  end

  defp select_metric(:bounce_rate, "imported_exit_pages") do
    wrap_alias([i], %{bounces: sum(i.bounces), __internal_visits: sum(i.exits)})
  end

  defp select_metric(:bounce_rate, "imported_entry_pages") do
    wrap_alias([i], %{bounces: sum(i.bounces), __internal_visits: sum(i.entrances)})
  end

  defp select_metric(:bounce_rate, _table) do
    wrap_alias([i], %{bounces: sum(i.bounces), __internal_visits: sum(i.visits)})
  end

  defp select_metric(:visit_duration, "imported_pages") do
    wrap_alias([i], %{visit_duration: 0})
  end

  defp select_metric(:visit_duration, "imported_exit_pages") do
    wrap_alias([i], %{visit_duration: sum(i.visit_duration), __internal_visits: sum(i.exits)})
  end

  defp select_metric(:visit_duration, "imported_entry_pages") do
    wrap_alias([i], %{visit_duration: sum(i.visit_duration), __internal_visits: sum(i.entrances)})
  end

  defp select_metric(:visit_duration, _table) do
    wrap_alias([i], %{visit_duration: sum(i.visit_duration), __internal_visits: sum(i.visits)})
  end

  defp select_metric(:views_per_visit, "imported_exit_pages") do
    wrap_alias([i], %{pageviews: sum(i.pageviews), __internal_visits: sum(i.exits)})
  end

  defp select_metric(:views_per_visit, "imported_entry_pages") do
    wrap_alias([i], %{pageviews: sum(i.pageviews), __internal_visits: sum(i.entrances)})
  end

  defp select_metric(:views_per_visit, _table) do
    wrap_alias([i], %{pageviews: sum(i.pageviews), __internal_visits: sum(i.visits)})
  end

  defp select_metric(:scroll_depth, "imported_pages") do
    wrap_alias([i], %{
      scroll_depth_sum: sum(i.scroll_depth),
      total_visitors: fragment("sumIf(?, isNotNull(?))", i.visitors, i.scroll_depth)
    })
  end

  defp select_metric(_metric, _table), do: %{}

  def group_imported_by(q, query) do
    Enum.reduce(query.dimensions, q, fn dimension, q ->
      q
      |> select_group_fields(dimension, shortname(query, dimension), query)
      |> filter_group_values(dimension)
      |> group_by([], selected_as(^shortname(query, dimension)))
    end)
  end

  defp select_group_fields(q, dimension, key, _query)
       when dimension in ["visit:source", "visit:referrer"] do
    select_merge_as(q, [i], %{
      key =>
        fragment(
          "if(empty(?), ?, ?)",
          field(i, ^dim(dimension)),
          @no_ref,
          field(i, ^dim(dimension))
        )
    })
  end

  defp select_group_fields(q, "event:page", key, _query) do
    select_merge_as(q, [i], %{key => i.page, time_on_page: sum(i.time_on_page)})
  end

  defp select_group_fields(q, dimension, key, _query)
       when dimension in ["visit:device", "visit:browser", "visit:channel"] do
    select_merge_as(q, [i], %{
      key =>
        fragment(
          "if(empty(?), ?, ?)",
          field(i, ^dim(dimension)),
          @not_set,
          field(i, ^dim(dimension))
        )
    })
  end

  defp select_group_fields(q, "visit:browser_version", key, _query) do
    select_merge_as(q, [i], %{
      key => fragment("if(empty(?), ?, ?)", i.browser_version, @not_set, i.browser_version)
    })
  end

  defp select_group_fields(q, "visit:os", key, _query) do
    select_merge_as(q, [i], %{
      key => fragment("if(empty(?), ?, ?)", i.operating_system, @not_set, i.operating_system)
    })
  end

  defp select_group_fields(q, "visit:os_version", key, _query) do
    select_merge_as(q, [i], %{
      key =>
        fragment(
          "if(empty(?), ?, ?)",
          i.operating_system_version,
          @not_set,
          i.operating_system_version
        )
    })
  end

  defp select_group_fields(q, "event:props:url", key, _query) do
    select_merge_as(q, [i], %{
      key => fragment("if(not empty(?), ?, ?)", i.link_url, i.link_url, @none)
    })
  end

  defp select_group_fields(q, "event:props:path", key, _query) do
    select_merge_as(q, [i], %{
      key => fragment("if(not empty(?), ?, ?)", i.path, i.path, @none)
    })
  end

  defp select_group_fields(q, "time:month", key, _query) do
    select_merge_as(q, [i], %{key => fragment("toStartOfMonth(?)", i.date)})
  end

  defp select_group_fields(q, dimension, key, _query)
       when dimension in ["time:hour", "time:day"] do
    select_merge_as(q, [i], %{key => i.date})
  end

  defp select_group_fields(q, "time:week", key, query) do
    date_range = Query.date_range(query)

    select_merge_as(q, [i], %{
      key => weekstart_not_before(i.date, ^date_range.first)
    })
  end

  defp select_group_fields(q, dimension, key, _query) do
    select_merge_as(q, [i], %{key => field(i, ^dim(dimension))})
  end

  @utm_dimensions [
    "visit:utm_source",
    "visit:utm_medium",
    "visit:utm_campaign",
    "visit:utm_term",
    "visit:utm_content"
  ]
  defp filter_group_values(q, dimension) when dimension in @utm_dimensions do
    dim = Plausible.Stats.Filters.without_prefix(dimension)

    where(q, [i], fragment("not empty(?)", field(i, ^dim)))
  end

  defp filter_group_values(q, "visit:country"), do: where(q, [i], i.country != "ZZ")
  defp filter_group_values(q, "visit:region"), do: where(q, [i], i.region != "")
  defp filter_group_values(q, "visit:city"), do: where(q, [i], i.city != 0 and not is_nil(i.city))

  defp filter_group_values(q, "visit:country_name"), do: where(q, [i], i.country_name != "ZZ")
  defp filter_group_values(q, "visit:region_name"), do: where(q, [i], i.region_name != "")
  defp filter_group_values(q, "visit:city_name"), do: where(q, [i], i.city_name != "")

  defp filter_group_values(q, _dimension), do: q

  def select_joined_dimensions(q, query) do
    Enum.reduce(query.dimensions, q, fn dimension, q ->
      select_joined_dimension(q, dimension, shortname(query, dimension))
    end)
  end

  defp select_joined_dimension(q, "visit:city", key) do
    select_merge_as(q, [s, i], %{
      key => fragment("greatest(?,?)", field(i, ^key), field(s, ^key))
    })
  end

  defp select_joined_dimension(q, "time:" <> _, key) do
    select_merge_as(q, [s, i], %{
      key => fragment("greatest(?, ?)", field(i, ^key), field(s, ^key))
    })
  end

  defp select_joined_dimension(q, _dimension, key) do
    select_merge_as(q, [s, i], %{
      key => fragment("if(empty(?), ?, ?)", field(s, ^key), field(i, ^key), field(s, ^key))
    })
  end

  def select_joined_metrics(q, []), do: q
  # NOTE: Reverse-engineering the native data bounces and total visit
  # durations to combine with imported data is inefficient. Instead both
  # queries should fetch bounces/total_visit_duration and visits and be
  # used as subqueries to a main query that then find the bounce rate/avg
  # visit_duration.

  def select_joined_metrics(q, [:visits | rest]) do
    q
    |> select_merge_as([s, i], %{visits: s.visits + i.visits})
    |> select_joined_metrics(rest)
  end

  def select_joined_metrics(q, [:visitors | rest]) do
    q
    |> select_merge_as([s, i], %{visitors: s.visitors + i.visitors})
    |> select_joined_metrics(rest)
  end

  def select_joined_metrics(q, [:events | rest]) do
    q
    |> select_merge_as([s, i], %{events: s.events + i.events})
    |> select_joined_metrics(rest)
  end

  def select_joined_metrics(q, [:pageviews | rest]) do
    q
    |> select_merge_as([s, i], %{pageviews: s.pageviews + i.pageviews})
    |> select_joined_metrics(rest)
  end

  def select_joined_metrics(q, [:views_per_visit | rest]) do
    q
    |> select_merge_as([s, i], %{
      views_per_visit:
        fragment(
          "if(? + ? > 0, round((? + ? * ?) / (? + ?), 2), 0)",
          s.__internal_visits,
          i.__internal_visits,
          i.pageviews,
          s.views_per_visit,
          s.__internal_visits,
          i.__internal_visits,
          s.__internal_visits
        )
    })
    |> select_joined_metrics(rest)
  end

  def select_joined_metrics(q, [:bounce_rate | rest]) do
    q
    |> select_merge_as([s, i], %{
      bounce_rate:
        fragment(
          "if(? + ? > 0, round(100 * (? + (? * ? / 100)) / (? + ?)), 0)",
          s.__internal_visits,
          i.__internal_visits,
          i.bounces,
          s.bounce_rate,
          s.__internal_visits,
          i.__internal_visits,
          s.__internal_visits
        )
    })
    |> select_joined_metrics(rest)
  end

  def select_joined_metrics(q, [:visit_duration | rest]) do
    q
    |> select_merge_as([s, i], %{
      visit_duration:
        fragment(
          """
          if(
            ? + ? > 0,
            round((? + ? * ?) / (? + ?), 0),
            0
          )
          """,
          s.__internal_visits,
          i.__internal_visits,
          i.visit_duration,
          s.visit_duration,
          s.__internal_visits,
          s.__internal_visits,
          i.__internal_visits
        )
    })
    |> select_joined_metrics(rest)
  end

  # The final `scroll_depth` gets selected at a later querybuilding step
  # (in `Plausible.Stats.SQL.SpecialMetrics.add/3`). But in order to avoid
  # having to join with imported data there again, we select the required
  # information from imported data here already.
  def select_joined_metrics(q, [:scroll_depth | rest]) do
    q
    |> select_merge_as([s, i], %{
      __internal_scroll_depth_sum: i.scroll_depth_sum,
      __internal_total_visitors: i.total_visitors
    })
    |> select_joined_metrics(rest)
  end

  # Ignored as it's calculated separately
  def select_joined_metrics(q, [metric | rest])
      when metric in [:conversion_rate, :group_conversion_rate, :percentage] do
    q
    |> select_joined_metrics(rest)
  end

  def select_joined_metrics(q, [metric | rest]) do
    q
    |> select_merge_as([s, i], %{metric => field(s, ^metric)})
    |> select_joined_metrics(rest)
  end

  defp dim(dimension), do: Plausible.Stats.Filters.without_prefix(dimension)
end
