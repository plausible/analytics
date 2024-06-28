defmodule Plausible.Stats.Imported do
  alias Plausible.Stats.Filters
  use Plausible.ClickhouseRepo

  import Ecto.Query
  import Plausible.Stats.Fragments

  alias Plausible.Stats.Base
  alias Plausible.Stats.Imported
  alias Plausible.Stats.Query

  @no_ref "Direct / None"
  @not_set "(not set)"
  @none "(none)"

  @property_to_table_mappings Imported.Base.property_to_table_mappings()

  @imported_properties Map.keys(@property_to_table_mappings) ++
                         Plausible.Imported.imported_custom_props()

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
    not is_nil(Imported.Base.decide_table(query))
  end

  def merge_imported_country_suggestions(native_q, _site, %Plausible.Stats.Query{
        include_imported: false
      }) do
    native_q
  end

  def merge_imported_country_suggestions(native_q, site, query) do
    supports_filter_set? =
      Enum.all?(query.filters, fn filter ->
        [_, filtered_prop | _] = filter
        @property_to_table_mappings[filtered_prop] == "imported_locations"
      end)

    if supports_filter_set? do
      native_q =
        native_q
        |> exclude(:order_by)
        |> exclude(:select)
        |> select([e], %{country_code: e.country_code, count: fragment("count(*)")})

      imported_q =
        from i in Imported.Base.query_imported("imported_locations", site, query),
          group_by: i.country,
          select_merge: %{country_code: i.country, count: fragment("sum(?)", i.pageviews)}

      from(s in subquery(native_q),
        full_join: i in subquery(imported_q),
        on: s.country_code == i.country_code,
        select:
          fragment("if(not empty(?), ?, ?)", s.country_code, s.country_code, i.country_code),
        order_by: [desc: fragment("? + ?", s.count, i.count)]
      )
    else
      native_q
    end
  end

  def merge_imported_region_suggestions(native_q, _site, %Plausible.Stats.Query{
        include_imported: false
      }) do
    native_q
  end

  def merge_imported_region_suggestions(native_q, site, query) do
    supports_filter_set? =
      Enum.all?(query.filters, fn filter ->
        [_, filtered_prop | _] = filter
        @property_to_table_mappings[filtered_prop] == "imported_locations"
      end)

    if supports_filter_set? do
      native_q =
        native_q
        |> exclude(:order_by)
        |> exclude(:select)
        |> select([e], %{region_code: e.subdivision1_code, count: fragment("count(*)")})

      imported_q =
        from i in Imported.Base.query_imported("imported_locations", site, query),
          where: i.region != "",
          group_by: i.region,
          select_merge: %{region_code: i.region, count: fragment("sum(?)", i.pageviews)}

      from(s in subquery(native_q),
        full_join: i in subquery(imported_q),
        on: s.region_code == i.region_code,
        select: fragment("if(not empty(?), ?, ?)", s.region_code, s.region_code, i.region_code),
        order_by: [desc: fragment("? + ?", s.count, i.count)]
      )
    else
      native_q
    end
  end

  def merge_imported_city_suggestions(native_q, _site, %Plausible.Stats.Query{
        include_imported: false
      }) do
    native_q
  end

  def merge_imported_city_suggestions(native_q, site, query) do
    supports_filter_set? =
      Enum.all?(query.filters, fn filter ->
        [_, filtered_prop | _] = filter
        @property_to_table_mappings[filtered_prop] == "imported_locations"
      end)

    if supports_filter_set? do
      native_q =
        native_q
        |> exclude(:order_by)
        |> exclude(:select)
        |> select([e], %{city_id: e.city_geoname_id, count: fragment("count(*)")})

      imported_q =
        from i in Imported.Base.query_imported("imported_locations", site, query),
          where: i.city != 0,
          group_by: i.city,
          select_merge: %{city_id: i.city, count: fragment("sum(?)", i.pageviews)}

      from(s in subquery(native_q),
        full_join: i in subquery(imported_q),
        on: s.city_id == i.city_id,
        select: fragment("if(? > 0, ?, ?)", s.city_id, s.city_id, i.city_id),
        order_by: [desc: fragment("? + ?", s.count, i.count)]
      )
    else
      native_q
    end
  end

  def merge_imported_filter_suggestions(
        native_q,
        _site,
        %Plausible.Stats.Query{include_imported: false},
        _filter_name,
        _filter_search
      ) do
    native_q
  end

  def merge_imported_filter_suggestions(
        native_q,
        site,
        query,
        filter_name,
        filter_query
      ) do
    {table, db_field} = expand_suggestions_field(filter_name)

    supports_filter_set? =
      Enum.all?(query.filters, fn filter ->
        [_, filtered_prop | _] = filter
        @property_to_table_mappings[filtered_prop] == table
      end)

    if supports_filter_set? do
      native_q =
        native_q
        |> exclude(:order_by)
        |> exclude(:select)
        |> select([e], %{name: field(e, ^filter_name), count: fragment("count(*)")})

      imported_q =
        from i in Imported.Base.query_imported(table, site, query),
          where: fragment("? ilike ?", field(i, ^db_field), ^filter_query),
          group_by: field(i, ^db_field),
          select_merge: %{name: field(i, ^db_field), count: fragment("sum(?)", i.pageviews)}

      from(s in subquery(native_q),
        full_join: i in subquery(imported_q),
        on: s.name == i.name,
        select: fragment("if(not empty(?), ?, ?)", s.name, s.name, i.name),
        order_by: [desc: fragment("? + ?", s.count, i.count)],
        limit: 25
      )
    else
      native_q
    end
  end

  @filter_suggestions_mapping %{
    referrer_source: :source,
    screen_size: :device,
    pathname: :page
  }

  defp expand_suggestions_field(filter_name) do
    db_field = Map.get(@filter_suggestions_mapping, filter_name, filter_name)

    property =
      case db_field do
        :operating_system -> :os
        :operating_system_version -> :os_version
        other -> other
      end

    table_by_visit = Map.get(@property_to_table_mappings, "visit:#{property}")
    table_by_event = Map.get(@property_to_table_mappings, "event:#{property}")
    table = table_by_visit || table_by_event

    {table, db_field}
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

  # Note: Only called for APIv2, old APIs use merge_imported_pageview_goals
  def merge_imported(q, site, %Query{dimensions: ["event:goal"]} = query, metrics)
      when query.v2 do
    {events, page_regexes} = Filters.Utils.split_goals_query_expressions(query.preloaded_goals)

    events_q =
      "imported_custom_events"
      |> Imported.Base.query_imported(site, query)
      |> where([i], i.visitors > 0)
      |> select_merge([i], %{
        dim0: selected_as(fragment("-indexOf(?, ?)", ^events, i.name), :dim0)
      })
      |> select_imported_metrics(metrics)
      |> group_by([], selected_as(:dim0))
      |> where([], selected_as(:dim0) != 0)

    pages_q =
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
        dim0: type(fragment("?", index), :integer)
      })
      |> select_imported_metrics(metrics)

    q
    |> naive_dimension_join(events_q, metrics)
    |> naive_dimension_join(pages_q, metrics)
  end

  def merge_imported(q, site, %Query{dimensions: [dimension]} = query, metrics)
      when dimension in @imported_properties do
    dim = Plausible.Stats.Filters.without_prefix(dimension)

    imported_q =
      site
      |> Imported.Base.query_imported(query)
      |> where([i], i.visitors > 0)
      |> group_imported_by(dim, query)
      |> select_imported_metrics(metrics)

    join_on =
      case dim do
        _ when dim in [:url, :path] and not query.v2 ->
          dynamic([s, i], s.breakdown_prop_value == i.breakdown_prop_value)

        :os_version when not query.v2 ->
          dynamic([s, i], s.os == i.os and s.os_version == i.os_version)

        :browser_version when not query.v2 ->
          dynamic([s, i], s.browser == i.browser and s.browser_version == i.browser_version)

        dim ->
          dynamic([s, i], field(s, ^shortname(query, dim)) == field(i, ^shortname(query, dim)))
      end

    from(s in Ecto.Query.subquery(q),
      full_join: i in subquery(imported_q),
      on: ^join_on,
      select: %{}
    )
    |> select_joined_dimension(dim, query)
    |> select_joined_metrics(metrics)
    |> apply_order_by(query, metrics)
  end

  def merge_imported(q, site, %Query{dimensions: []} = query, metrics) do
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
    if Imported.Base.decide_table(query) == "imported_pages" do
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
      |> select_joined_dimension(:name, query)
      |> select_joined_metrics(metrics)
    else
      q
    end
  end

  def total_imported_visitors(site, query) do
    site
    |> Imported.Base.query_imported(query)
    |> select_merge([i], %{total_visitors: fragment("sum(?)", i.visitors)})
  end

  # :TRICKY: Handle backwards compatibility with old breakdown module
  defp shortname(query, _dim) when query.v2, do: :dim0
  defp shortname(_query, dim), do: dim

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
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_pages", _}}} = q,
         [:bounce_rate | rest]
       ) do
    q
    |> select_merge([i], %{
      bounces: 0,
      __internal_visits: 0
    })
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

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_exit_pages", _}}} = q,
         [:bounce_rate | rest]
       ) do
    q
    |> select_merge([i], %{
      bounces: sum(i.bounces),
      __internal_visits: sum(i.exits)
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
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_pages", _}}} = q,
         [:visit_duration | rest]
       ) do
    q
    |> select_merge([i], %{
      visit_duration: 0,
      __internal_visits: 0
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

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_exit_pages", _}}} = q,
         [:visit_duration | rest]
       ) do
    q
    |> select_merge([i], %{
      visit_duration: sum(i.visit_duration),
      __internal_visits: sum(i.exits)
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

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_entry_pages", _}}} = q,
         [:views_per_visit | rest]
       ) do
    q
    |> where([i], i.pageviews > 0)
    |> select_merge([i], %{
      pageviews: sum(i.pageviews),
      __internal_visits: sum(i.entrances)
    })
    |> select_imported_metrics(rest)
  end

  defp select_imported_metrics(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"imported_exit_pages", _}}} = q,
         [:views_per_visit | rest]
       ) do
    q
    |> where([i], i.pageviews > 0)
    |> select_merge([i], %{
      pageviews: sum(i.pageviews),
      __internal_visits: sum(i.exits)
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

  defp group_imported_by(q, dim, query) when dim in [:source, :referrer] do
    q
    |> group_by([i], field(i, ^dim))
    |> select_merge([i], %{
      ^shortname(query, dim) =>
        fragment(
          "if(empty(?), ?, ?)",
          field(i, ^dim),
          @no_ref,
          field(i, ^dim)
        )
    })
  end

  defp group_imported_by(q, dim, query)
       when dim in [:utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content] do
    q
    |> group_by([i], field(i, ^dim))
    |> where([i], fragment("not empty(?)", field(i, ^dim)))
    |> select_merge([i], %{^shortname(query, dim) => field(i, ^dim)})
  end

  defp group_imported_by(q, :page, query) do
    q
    |> group_by([i], i.page)
    |> select_merge([i], %{^shortname(query, :page) => i.page, time_on_page: sum(i.time_on_page)})
  end

  defp group_imported_by(q, :country, query) do
    q
    |> group_by([i], i.country)
    |> where([i], i.country != "ZZ")
    |> select_merge([i], %{^shortname(query, :country) => i.country})
  end

  defp group_imported_by(q, :region, query) do
    q
    |> group_by([i], i.region)
    |> where([i], i.region != "")
    |> select_merge([i], %{^shortname(query, :region) => i.region})
  end

  defp group_imported_by(q, :city, query) do
    q
    |> group_by([i], i.city)
    |> where([i], i.city != 0 and not is_nil(i.city))
    |> select_merge([i], %{^shortname(query, :city) => i.city})
  end

  defp group_imported_by(q, dim, query) when dim in [:device, :browser] do
    q
    |> group_by([i], field(i, ^dim))
    |> select_merge([i], %{
      ^shortname(query, dim) =>
        fragment("if(empty(?), ?, ?)", field(i, ^dim), @not_set, field(i, ^dim))
    })
  end

  defp group_imported_by(q, :browser_version, query) do
    q
    |> group_by([i], [i.browser, i.browser_version])
    |> select_merge([i], %{
      ^shortname(query, :browser) =>
        fragment("if(empty(?), ?, ?)", i.browser, @not_set, i.browser),
      ^shortname(query, :browser_version) =>
        fragment(
          "if(empty(?), ?, ?)",
          i.browser_version,
          @not_set,
          i.browser_version
        )
    })
  end

  defp group_imported_by(q, :os, query) do
    q
    |> group_by([i], i.operating_system)
    |> select_merge([i], %{
      ^shortname(query, :os) =>
        fragment("if(empty(?), ?, ?)", i.operating_system, @not_set, i.operating_system)
    })
  end

  defp group_imported_by(q, :os_version, query) do
    q
    |> group_by([i], [i.operating_system, i.operating_system_version])
    |> select_merge([i], %{
      ^shortname(query, :os) =>
        fragment("if(empty(?), ?, ?)", i.operating_system, @not_set, i.operating_system),
      ^shortname(query, :os_version) =>
        fragment(
          "if(empty(?), ?, ?)",
          i.operating_system_version,
          @not_set,
          i.operating_system_version
        )
    })
  end

  defp group_imported_by(q, dim, query) when dim in [:entry_page, :exit_page] do
    q
    |> group_by([i], field(i, ^dim))
    |> select_merge([i], %{^shortname(query, dim) => field(i, ^dim)})
  end

  defp group_imported_by(q, :name, query) do
    q
    |> group_by([i], i.name)
    |> select_merge([i], %{^shortname(query, :name) => i.name})
  end

  defp group_imported_by(q, :url, query) when query.v2 do
    q
    |> group_by([i], i.link_url)
    |> select_merge([i], %{
      ^shortname(query, :url) => fragment("if(not empty(?), ?, ?)", i.link_url, i.link_url, @none)
    })
  end

  defp group_imported_by(q, :url, _query) do
    q
    |> group_by([i], i.link_url)
    |> select_merge([i], %{
      breakdown_prop_value: fragment("if(not empty(?), ?, ?)", i.link_url, i.link_url, @none)
    })
  end

  defp group_imported_by(q, :path, query) when query.v2 do
    q
    |> group_by([i], i.path)
    |> select_merge([i], %{
      ^shortname(query, :path) => fragment("if(not empty(?), ?, ?)", i.path, i.path, @none)
    })
  end

  defp group_imported_by(q, :path, _query) do
    q
    |> group_by([i], i.path)
    |> select_merge([i], %{
      breakdown_prop_value: fragment("if(not empty(?), ?, ?)", i.path, i.path, @none)
    })
  end

  defp select_joined_dimension(q, :city, query) do
    select_merge(q, [s, i], %{
      ^shortname(query, :city) => fragment("greatest(?,?)", i.city, s.city)
    })
  end

  defp select_joined_dimension(q, :os_version, query) when not query.v2 do
    select_merge(q, [s, i], %{
      os: fragment("if(empty(?), ?, ?)", s.os, i.os, s.os),
      os_version: fragment("if(empty(?), ?, ?)", s.os_version, i.os_version, s.os_version)
    })
  end

  defp select_joined_dimension(q, :browser_version, query) when not query.v2 do
    select_merge(q, [s, i], %{
      browser: fragment("if(empty(?), ?, ?)", s.browser, i.browser, s.browser),
      browser_version:
        fragment("if(empty(?), ?, ?)", s.browser_version, i.browser_version, s.browser_version)
    })
  end

  defp select_joined_dimension(q, dim, query) when dim in [:url, :path] and not query.v2 do
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

  defp select_joined_dimension(q, dim, query) do
    select_merge(q, [s, i], %{
      ^shortname(query, dim) =>
        fragment(
          "if(empty(?), ?, ?)",
          field(s, ^shortname(query, dim)),
          field(i, ^shortname(query, dim)),
          field(s, ^shortname(query, dim))
        )
    })
  end

  defp select_joined_metrics(q, []), do: q
  # NOTE: Reverse-engineering the native data bounces and total visit
  # durations to combine with imported data is inefficient. Instead both
  # queries should fetch bounces/total_visit_duration and visits and be
  # used as subqueries to a main query that then find the bounce rate/avg
  # visit_duration.

  defp select_joined_metrics(q, [:visits | rest]) do
    q
    |> select_merge([s, i], %{visits: selected_as(s.visits + i.visits, :visits)})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:visitors | rest]) do
    q
    |> select_merge([s, i], %{visitors: selected_as(s.visitors + i.visitors, :visitors)})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:events | rest]) do
    q
    |> select_merge([s, i], %{events: selected_as(s.events + i.events, :events)})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [:pageviews | rest]) do
    q
    |> select_merge([s, i], %{pageviews: selected_as(s.pageviews + i.pageviews, :pageviews)})
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

  defp select_joined_metrics(q, [:sample_percent | rest]) do
    q
    |> select_merge([s, i], %{sample_percent: s.sample_percent})
    |> select_joined_metrics(rest)
  end

  defp select_joined_metrics(q, [_ | rest]) do
    q
    |> select_joined_metrics(rest)
  end

  defp apply_order_by(q, %Query{v2: true}, _), do: q

  defp apply_order_by(q, query, [:visitors | rest]) do
    order_by(q, [s, i], desc: s.visitors + i.visitors)
    |> apply_order_by(query, rest)
  end

  defp apply_order_by(q, _query, _), do: q

  defp naive_dimension_join(q1, q2, metrics) do
    from(a in Ecto.Query.subquery(q1),
      full_join: b in subquery(q2),
      on: a.dim0 == b.dim0,
      select: %{
        dim0: fragment("coalesce(?, ?)", a.dim0, b.dim0)
      }
    )
    |> select_joined_metrics(metrics)
  end
end
