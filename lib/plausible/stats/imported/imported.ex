defmodule Plausible.Stats.Imported do
  use Plausible.ClickhouseRepo
  alias Plausible.Stats.{Query, Base, Imported}

  import Ecto.Query
  import Plausible.Stats.Fragments

  @no_ref "Direct / None"
  @not_set "(not set)"
  @none "(none)"

  @property_to_table_mappings %{
    "visit:source" => "imported_sources",
    "visit:referrer" => "imported_sources",
    "visit:utm_source" => "imported_sources",
    "visit:utm_medium" => "imported_sources",
    "visit:utm_campaign" => "imported_sources",
    "visit:utm_term" => "imported_sources",
    "visit:utm_content" => "imported_sources",
    "visit:entry_page" => "imported_entry_pages",
    "visit:exit_page" => "imported_exit_pages",
    "visit:country" => "imported_locations",
    "visit:region" => "imported_locations",
    "visit:city" => "imported_locations",
    "visit:device" => "imported_devices",
    "visit:browser" => "imported_browsers",
    "visit:browser_version" => "imported_browsers",
    "visit:os" => "imported_operating_systems",
    "visit:os_version" => "imported_operating_systems",
    "event:page" => "imported_pages",
    "event:name" => "imported_custom_events",
    "event:props:url" => "imported_custom_events",
    "event:props:path" => "imported_custom_events"
  }

  def property_to_table_mappings(), do: @property_to_table_mappings

  @imported_properties Map.keys(@property_to_table_mappings)

  @goals_with_url Plausible.Imported.goals_with_url()

  def goals_with_url(), do: @goals_with_url

  @goals_with_path Plausible.Imported.goals_with_path()

  def goals_with_path(), do: @goals_with_path

  @doc """
  Returns a boolean indicating whether the combination of filters and
  breakdown property is possible to query from the imported tables.

  Usually, when no filters are used, the imported schema supports the
  query. There is one exception though - breakdown by a custom property.
  We are currently importing only two custom properties - `url` and `path.
  Both these properties can only be used with their special goal filter
  (see `@goals_with_url` and `@goals_with_path`).
  """
  def schema_supports_query?(query) do
    query = drop_redundant_filters(query)

    # TODO: We want to be able to filter by a goal and still
    # show a goal breakdown
    case query.property do
      "event:goal" -> query.filters == []
      _ -> not is_nil(Imported.Base.decide_table(query))
    end
  end

  @doc """
  This function gets rid of filters that do not make sense in the context
  of imported data, for example `event:name == "pageview"`. They will be
  ignored when deciding whether to include imported data in the query or
  not, as well as when actually applying those filters to the query.
  """
  def drop_redundant_filters(query) do
    struct!(query,
      filters:
        Enum.reject(query.filters, fn
          [:is, "event:name", "pageview"] -> true
          _ -> false
        end)
    )
  end

  def merge_imported_timeseries(native_q, _, %Plausible.Stats.Query{include_imported: false}, _),
    do: native_q

  def merge_imported_timeseries(
        native_q,
        site,
        query,
        metrics
      ) do
    imported_q =
      site
      |> Imported.Base.query_imported(query)
      |> select_imported_metrics(metrics)
      |> apply_interval(query, site)

    from(s in Ecto.Query.subquery(native_q),
      full_join: i in subquery(imported_q),
      on: s.date == i.date,
      select: %{date: fragment("greatest(?, ?)", s.date, i.date)}
    )
    |> select_joined_metrics(metrics)
  end

  defp apply_interval(imported_q, %Plausible.Stats.Query{interval: "month"}, _site) do
    imported_q
    |> group_by([i], fragment("toStartOfMonth(?)", i.date))
    |> select_merge([i], %{date: fragment("toStartOfMonth(?)", i.date)})
  end

  defp apply_interval(imported_q, %Plausible.Stats.Query{interval: "week"} = query, _site) do
    imported_q
    |> group_by([i], weekstart_not_before(i.date, ^query.date_range.first))
    |> select_merge([i], %{date: weekstart_not_before(i.date, ^query.date_range.first)})
  end

  defp apply_interval(imported_q, _query, _site) do
    imported_q
    |> group_by([i], i.date)
    |> select_merge([i], %{date: i.date})
  end

  def merge_imported(q, _, %Query{include_imported: false}, _), do: q

  def merge_imported(q, site, %Query{property: property} = query, metrics)
      when property in @imported_properties do
    dim = Plausible.Stats.Filters.without_prefix(property)

    imported_q =
      site
      |> Imported.Base.query_imported(query)
      |> where([i], i.visitors > 0)
      |> maybe_apply_filter(query, property, dim)
      |> group_imported_by(dim)
      |> select_imported_metrics(metrics)

    join_on =
      case dim do
        _ when dim in [:url, :path] ->
          dynamic([s, i], s.breakdown_prop_value == i.breakdown_prop_value)

        :os_version ->
          dynamic([s, i], s.os == i.os and s.os_version == i.os_version)

        :browser_version ->
          dynamic([s, i], s.browser == i.browser and s.browser_version == i.browser_version)

        dim ->
          dynamic([s, i], field(s, ^dim) == field(i, ^dim))
      end

    from(s in Ecto.Query.subquery(q),
      full_join: i in subquery(imported_q),
      on: ^join_on,
      select: %{}
    )
    |> select_joined_dimension(dim)
    |> select_joined_metrics(metrics)
    |> apply_order_by(metrics)
  end

  def merge_imported(q, site, %Query{property: nil} = query, metrics) do
    imported_q =
      site
      |> Imported.Base.query_imported(query)
      |> select_imported_metrics(metrics)

    from(
      s in subquery(q),
      cross_join: i in subquery(imported_q),
      select: %{}
    )
    |> select_joined_metrics(metrics)
  end

  def merge_imported(q, _, _, _), do: q

  def merge_imported_pageview_goals(q, _, %Query{include_imported: false}, _, _), do: q

  def merge_imported_pageview_goals(q, site, query, page_exprs, metrics) do
    page_regexes = Enum.map(page_exprs, &Base.page_regex/1)

    imported_q =
      "imported_pages"
      |> Imported.Base.query_imported(site, query)
      |> where([i], i.visitors > 0)
      |> where(
        [i],
        fragment("notEmpty(multiMatchAllIndices(?, ?) as indices)", i.page, ^page_regexes)
      )
      |> join(:array, index in fragment("indices"))
      |> group_by([_i, index], index)
      |> select_merge([_i, index], %{
        name: fragment("concat('Visit ', ?[?])", ^page_exprs, index)
      })
      |> select_imported_metrics(metrics)

    from(s in Ecto.Query.subquery(q),
      full_join: i in subquery(imported_q),
      on: s.name == i.name,
      select: %{}
    )
    |> select_joined_dimension(:name)
    |> select_joined_metrics(metrics)
  end

  def total_imported_visitors(site, query) do
    site
    |> Imported.Base.query_imported(query)
    |> select_merge([i], %{total_visitors: fragment("sum(?)", i.visitors)})
  end

  defp maybe_apply_filter(q, query, property, dim) do
    case Query.get_filter(query, property) do
      [:member, _, list] -> where(q, [i], field(i, ^dim) in ^list)
      _ -> q
    end
  end

  defp select_imported_metrics(q, []), do: q

  defp select_imported_metrics(q, [:visitors | rest]) do
    q
    |> select_merge([i], %{visitors: sum(i.visitors)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_custom_events", _}}} = q,
         [:events | rest]
       ) do
    q
    |> select_merge([i], %{events: sum(i.events)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [:events | rest]) do
    q
    |> select_merge([i], %{events: sum(i.pageviews)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_exit_pages", _}}} = q,
         [:visits | rest]
       ) do
    q
    |> select_merge([i], %{visits: sum(i.exits)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_entry_pages", _}}} = q,
         [:visits | rest]
       ) do
    q
    |> select_merge([i], %{visits: sum(i.entrances)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [:visits | rest]) do
    q
    |> select_merge([i], %{visits: sum(i.visits)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_custom_events", _}}} = q,
         [:pageviews | rest]
       ) do
    q
    |> select_merge([i], %{pageviews: 0})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [:pageviews | rest]) do
    q
    |> where([i], i.pageviews > 0)
    |> select_merge([i], %{pageviews: sum(i.pageviews)})
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_entry_pages", _}}} = q,
         [:bounce_rate | rest]
       ) do
    q
    |> select_merge([i], %{
      bounces: sum(i.bounces),
      __internal_visits: sum(i.entrances)
    })
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [:bounce_rate | rest]) do
    q
    |> select_merge([i], %{
      bounces: sum(i.bounces),
      __internal_visits: sum(i.visits)
    })
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_entry_pages", _}}} = q,
         [:visit_duration | rest]
       ) do
    q
    |> select_merge([i], %{
      visit_duration: sum(i.visit_duration),
      __internal_visits: sum(i.entrances)
    })
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [:visit_duration | rest]) do
    q
    |> select_merge([i], %{
      visit_duration: sum(i.visit_duration),
      __internal_visits: sum(i.visits)
    })
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [:views_per_visit | rest]) do
    q
    |> where([i], i.pageviews > 0)
    |> select_merge([i], %{
      pageviews: sum(i.pageviews),
      __internal_visits: sum(i.visits)
    })
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(q, [_ | rest]) do
    q
    |> select_imported_metrics(rest)
  end

  defp group_imported_by(q, dim) when dim in [:source, :referrer] do
    q
    |> group_by([i], field(i, ^dim))
    |> select_merge([i], %{
      ^dim => fragment("if(empty(?), ?, ?)", field(i, ^dim), @no_ref, field(i, ^dim))
    })
  end

  defp group_imported_by(q, dim)
       when dim in [:utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content] do
    q
    |> group_by([i], field(i, ^dim))
    |> where([i], fragment("not empty(?)", field(i, ^dim)))
    |> select_merge([i], %{^dim => field(i, ^dim)})
  end

  defp group_imported_by(q, :page) do
    q
    |> group_by([i], i.page)
    |> select_merge([i], %{page: i.page, time_on_page: sum(i.time_on_page)})
  end

  defp group_imported_by(q, :country) do
    q
    |> group_by([i], i.country)
    |> where([i], i.country != "ZZ")
    |> select_merge([i], %{country: i.country})
  end

  defp group_imported_by(q, :region) do
    q
    |> group_by([i], i.region)
    |> where([i], i.region != "")
    |> select_merge([i], %{region: i.region})
  end

  defp group_imported_by(q, :city) do
    q
    |> group_by([i], i.city)
    |> where([i], i.city != 0 and not is_nil(i.city))
    |> select_merge([i], %{city: i.city})
  end

  defp group_imported_by(q, dim) when dim in [:device, :browser] do
    q
    |> group_by([i], field(i, ^dim))
    |> select_merge([i], %{
      ^dim => fragment("if(empty(?), ?, ?)", field(i, ^dim), @not_set, field(i, ^dim))
    })
  end

  defp group_imported_by(q, :browser_version) do
    q
    |> group_by([i], [i.browser, i.browser_version])
    |> select_merge([i], %{
      browser: fragment("if(empty(?), ?, ?)", i.browser, @not_set, i.browser),
      browser_version:
        fragment(
          "if(empty(?), ?, ?)",
          i.browser_version,
          @not_set,
          i.browser_version
        )
    })
  end

  defp group_imported_by(q, :os) do
    q
    |> group_by([i], i.operating_system)
    |> select_merge([i], %{
      os: fragment("if(empty(?), ?, ?)", i.operating_system, @not_set, i.operating_system)
    })
  end

  defp group_imported_by(q, :os_version) do
    q
    |> group_by([i], [i.operating_system, i.operating_system_version])
    |> select_merge([i], %{
      os: fragment("if(empty(?), ?, ?)", i.operating_system, @not_set, i.operating_system),
      os_version:
        fragment(
          "if(empty(?), ?, ?)",
          i.operating_system_version,
          @not_set,
          i.operating_system_version
        )
    })
  end

  defp group_imported_by(q, dim) when dim in [:entry_page, :exit_page] do
    q
    |> group_by([i], field(i, ^dim))
    |> select_merge([i], %{^dim => field(i, ^dim)})
  end

  defp group_imported_by(q, :name) do
    q
    |> group_by([i], i.name)
    |> select_merge([i], %{name: i.name})
  end

  defp group_imported_by(q, :url) do
    q
    |> group_by([i], i.link_url)
    |> select_merge([i], %{
      breakdown_prop_value: fragment("if(not empty(?), ?, ?)", i.link_url, i.link_url, @none)
    })
  end

  defp group_imported_by(q, :path) do
    q
    |> group_by([i], i.path)
    |> select_merge([i], %{
      breakdown_prop_value: fragment("if(not empty(?), ?, ?)", i.path, i.path, @none)
    })
  end

  defp select_joined_dimension(q, :city) do
    select_merge(q, [s, i], %{
      city: fragment("greatest(?,?)", i.city, s.city)
    })
  end

  defp select_joined_dimension(q, :os_version) do
    select_merge(q, [s, i], %{
      os: fragment("if(empty(?), ?, ?)", s.os, i.os, s.os),
      os_version: fragment("if(empty(?), ?, ?)", s.os_version, i.os_version, s.os_version)
    })
  end

  defp select_joined_dimension(q, :browser_version) do
    select_merge(q, [s, i], %{
      browser: fragment("if(empty(?), ?, ?)", s.browser, i.browser, s.browser),
      browser_version:
        fragment("if(empty(?), ?, ?)", s.browser_version, i.browser_version, s.browser_version)
    })
  end

  defp select_joined_dimension(q, dim) when dim in [:url, :path] do
    select_merge(q, [s, i], %{
      breakdown_prop_value:
        fragment(
          "if(empty(?), ?, ?)",
          s.breakdown_prop_value,
          i.breakdown_prop_value,
          s.breakdown_prop_value
        )
    })
  end

  defp select_joined_dimension(q, dim) do
    select_merge(q, [s, i], %{
      ^dim => fragment("if(empty(?), ?, ?)", field(s, ^dim), field(i, ^dim), field(s, ^dim))
    })
  end

  defp select_joined_metrics(q, []), do: q
  # TODO: Reverse-engineering the native data bounces and total visit
  # durations to combine with imported data is inefficient. Instead both
  # queries should fetch bounces/total_visit_duration and visits and be
  # used as subqueries to a main query that then find the bounce rate/avg
  # visit_duration.

  defp select_joined_metrics(q, [:visits | rest]) do
    q
    |> select_merge([s, i], %{visits: s.visits + i.visits})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:visitors | rest]) do
    q
    |> select_merge([s, i], %{visitors: selected_as(s.visitors + i.visitors, :visitors)})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:events | rest]) do
    q
    |> select_merge([s, i], %{events: s.events + i.events})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:pageviews | rest]) do
    q
    |> select_merge([s, i], %{pageviews: s.pageviews + i.pageviews})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:views_per_visit | rest]) do
    q
    |> select_merge([s, i], %{
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

  defp select_joined_metrics(q, [:bounce_rate | rest]) do
    q
    |> select_merge([s, i], %{
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

  defp select_joined_metrics(q, [:visit_duration | rest]) do
    q
    |> select_merge([s, i], %{
      visit_duration:
        fragment(
          """
          if(
            ? + ? > 0,
            round((? + ? * ?) / (? + ?), 1),
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

  defp select_joined_metrics(q, [:sample_percent | rest]) do
    q
    |> select_merge([s, i], %{sample_percent: s.sample_percent})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [_ | rest]) do
    q
    |> select_joined_metrics(rest)
  end

  defp apply_order_by(q, [:visitors | rest]) do
    order_by(q, [s, i], desc: s.visitors + i.visitors)
    |> apply_order_by(rest)
  end

  defp apply_order_by(q, _), do: q
end
