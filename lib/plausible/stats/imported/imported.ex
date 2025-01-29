defmodule Plausible.Stats.Imported do
  use Plausible.ClickhouseRepo
  use Plausible.Stats.SQL.Fragments

  import Ecto.Query
  import Plausible.Stats.Imported.SQL.Expression

  alias Plausible.Stats.Imported
  alias Plausible.Stats.Query
  alias Plausible.Stats.SQL.QueryBuilder

  @property_to_table_mappings Imported.Base.property_to_table_mappings()

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
    length(Imported.Base.decide_tables(query)) > 0
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
    acquisition_channel: :channel,
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

  def merge_imported(q, _, %Query{include_imported: false}, _), do: q

  def merge_imported(q, site, %Query{dimensions: []} = query, metrics) do
    q = paginate_optimization(q, query)

    imported_q =
      site
      |> Imported.Base.query_imported(query)
      |> select_imported_metrics(metrics)
      |> paginate_optimization(query)

    from(
      s in subquery(q),
      cross_join: i in subquery(imported_q),
      select: %{}
    )
    |> select_joined_metrics(metrics)
  end

  def merge_imported(q, site, %Query{dimensions: ["event:goal"]} = query, metrics) do
    %{
      indices: goal_indices,
      types: goal_types,
      event_names: goal_event_names,
      page_regexes: goal_page_regexes
    } =
      query.preloaded_goals.matching_toplevel_filters
      |> Plausible.Goals.decompose()

    Imported.Base.decide_tables(query)
    |> Enum.map(fn
      "imported_custom_events" ->
        Imported.Base.query_imported("imported_custom_events", site, query)
        |> where([i], i.visitors > 0)
        |> select_merge_as([i], %{
          dim0:
            type(
              fragment(
                "indexOf(?, ?)",
                type(^goal_event_names, {:array, :string}),
                i.name
              ),
              :integer
            )
        })
        |> select_imported_metrics(metrics)
        |> group_by([], selected_as(:dim0))
        |> where([], selected_as(:dim0) != 0)

      "imported_pages" ->
        Imported.Base.query_imported("imported_pages", site, query)
        |> where([i], i.visitors > 0)
        |> where(
          [i],
          fragment(
            """
            notEmpty(
              arrayFilter(
                goal_idx -> ?[goal_idx] = 'page' AND match(?, ?[goal_idx]),
                ?
              ) as indices
            )
            """,
            type(^goal_types, {:array, :string}),
            i.page,
            type(^goal_page_regexes, {:array, :string}),
            type(^goal_indices, {:array, :integer})
          )
        )
        |> join(:inner, [_i], index in fragment("indices"), hints: "ARRAY", on: true)
        |> group_by([_i, index], index)
        |> select_merge_as([_i, index], %{
          dim0: type(fragment("?", index), :integer)
        })
        |> select_imported_metrics(metrics)
    end)
    |> Enum.reduce(q, fn imports_q, q ->
      naive_dimension_join(q, imports_q, metrics)
    end)
  end

  def merge_imported(q, site, query, metrics) do
    if schema_supports_query?(query) do
      q = paginate_optimization(q, query)

      imported_q =
        site
        |> Imported.Base.query_imported(query)
        |> where([i], i.visitors > 0)
        |> group_imported_by(query)
        |> select_imported_metrics(metrics)
        |> paginate_optimization(query)

      from(s in subquery(q),
        full_join: i in subquery(imported_q),
        on: ^QueryBuilder.build_group_by_join(query),
        select: %{}
      )
      |> select_joined_dimensions(query)
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

  defp naive_dimension_join(q1, q2, metrics) do
    from(a in subquery(q1),
      full_join: b in subquery(q2),
      on: a.dim0 == b.dim0,
      select: %{}
    )
    |> select_merge_as([a, b], %{
      dim0: fragment("if(? != 0, ?, ?)", a.dim0, a.dim0, b.dim0)
    })
    |> select_joined_metrics(metrics)
  end

  # Optimization for cases when grouping by a very high cardinality column.
  #
  # Instead of joining all rows from main and imported tables, we limit the number of rows
  # in both tables to LIMIT N * 100.
  #
  # This speeds up cases where a site has millions of unique pathnames, reducing the time spent
  # JOINing tables by an order of magnitude.
  #
  # Note that this optimization is lossy as the true top N values can arise from outside the top C
  # items of either subquery. In practice though, this will give plausible results.
  #
  # We only apply this optimization in cases where we can deterministically ORDER BY. This covers
  # opening Plausible dashboard but not more complicated use-cases.
  defp paginate_optimization(q, query) do
    if is_map(query.pagination) and can_order_by?(query) do
      n = (query.pagination.limit + query.pagination.offset) * 100

      q
      |> QueryBuilder.build_order_by(query)
      |> limit(^n)
    else
      q
    end
  end

  defp can_order_by?(query) do
    Enum.all?(query.order_by, fn
      {:scroll_depth, _} -> false
      {metric, _direction} when is_atom(metric) -> metric in query.metrics
      _ -> true
    end)
  end
end
