defmodule Plausible.Stats.Breakdown do
  use Plausible.ClickhouseRepo
  use Plausible
  use Plausible.Stats.Fragments

  import Plausible.Stats.{Base, Imported}
  import Ecto.Query
  require OpenTelemetry.Tracer, as: Tracer
  alias Plausible.Stats.{Query, Util, TableDecider}

  @no_ref "Direct / None"
  @not_set "(not set)"

  @session_metrics [:visits, :bounce_rate, :visit_duration]

  @revenue_metrics on_full_build(do: Plausible.Stats.Goal.Revenue.revenue_metrics(), else: [])

  @event_metrics [:visitors, :pageviews, :events, :percentage] ++ @revenue_metrics

  # These metrics can be asked from the `breakdown/5` function,
  # but they are different from regular metrics such as `visitors`,
  # or `bounce_rate` - we cannot currently "select them" directly in
  # the db queries. Instead, we need to artificially append them to
  # the breakdown results later on.
  @computed_metrics [:conversion_rate, :total_visitors]

  def breakdown(site, query, property, metrics, pagination, opts \\ [])

  def breakdown(site, query, "event:goal" = property, metrics, pagination, opts) do
    site = Plausible.Repo.preload(site, :goals)

    {event_goals, pageview_goals} = Enum.split_with(site.goals, & &1.event_name)
    events = Enum.map(event_goals, & &1.event_name)
    event_query = %Query{query | filters: Map.put(query.filters, "event:name", {:member, events})}

    if !Keyword.get(opts, :skip_tracing), do: trace(query, property, metrics)

    no_revenue = {nil, metrics -- @revenue_metrics}

    {revenue_goals, metrics} =
      on_full_build do
        if Plausible.Billing.Feature.RevenueGoals.enabled?(site) do
          revenue_goals = Enum.filter(event_goals, &Plausible.Goal.Revenue.revenue?/1)
          metrics = if Enum.empty?(revenue_goals), do: metrics -- @revenue_metrics, else: metrics

          {revenue_goals, metrics}
        else
          no_revenue
        end
      else
        no_revenue
      end

    metrics_to_select = Util.maybe_add_visitors_metric(metrics) -- @computed_metrics

    event_q =
      if Enum.any?(event_goals) do
        site
        |> breakdown_events(event_query, "event:name", metrics_to_select)
        |> apply_pagination(pagination)
      else
        nil
      end

    page_q =
      if Enum.any?(pageview_goals) do
        page_exprs = Enum.map(pageview_goals, & &1.page_path)
        page_regexes = Enum.map(page_exprs, &page_regex/1)

        select_columns = metrics_to_select |> select_event_metrics |> mark_revenue_as_nil

        from(e in base_event_query(site, query),
          order_by: [desc: fragment("uniq(?)", e.user_id)],
          where:
            fragment(
              "notEmpty(multiMatchAllIndices(?, ?) as indices)",
              e.pathname,
              ^page_regexes
            ) and e.name == "pageview",
          array_join: index in fragment("indices"),
          group_by: index,
          select: %{
            name: fragment("concat('Visit ', ?[?])", ^page_exprs, index)
          }
        )
        |> select_merge(^select_columns)
        |> apply_pagination(pagination)
      else
        nil
      end

    full_q =
      case {event_q, page_q} do
        {nil, nil} ->
          nil

        {event_q, nil} ->
          event_q

        {nil, page_q} ->
          page_q

        {event_q, page_q} ->
          from(
            e in subquery(union_all(event_q, ^page_q)),
            order_by: [desc: e.visitors]
          )
          |> apply_pagination(pagination)
      end

    if full_q do
      full_q
      |> maybe_add_conversion_rate(site, query, metrics, include_imported: false)
      |> ClickhouseRepo.all(debug_label: :breakdown_by_goal)
      |> transform_keys(%{name: :goal})
      |> cast_revenue_metrics_to_money(revenue_goals)
      |> Util.keep_requested_metrics(metrics)
    else
      []
    end
  end

  def breakdown(site, query, "event:props:" <> custom_prop = property, metrics, pagination, opts) do
    {currency, metrics} =
      on_full_build do
        Plausible.Stats.Goal.Revenue.get_revenue_tracking_currency(site, query, metrics)
      else
        {nil, metrics}
      end

    metrics_to_select = Util.maybe_add_visitors_metric(metrics) -- @computed_metrics

    if !Keyword.get(opts, :skip_tracing), do: trace(query, property, metrics)

    breakdown_events(site, query, "event:props:" <> custom_prop, metrics_to_select)
    |> maybe_add_conversion_rate(site, query, metrics, include_imported: false)
    |> paginate_and_execute(metrics, pagination)
    |> transform_keys(%{breakdown_prop_value: custom_prop})
    |> Enum.map(&cast_revenue_metrics_to_money(&1, currency))
  end

  def breakdown(site, query, "event:page" = property, metrics, pagination, opts) do
    event_metrics =
      metrics
      |> Util.maybe_add_visitors_metric()
      |> Enum.filter(&(&1 in @event_metrics))

    event_result =
      site
      |> breakdown_events(query, property, event_metrics)
      |> maybe_add_group_conversion_rate(&breakdown_events/4, site, query, property, metrics)
      |> paginate_and_execute(metrics, pagination)
      |> maybe_add_time_on_page(site, query, metrics)

    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))

    new_query =
      case event_result do
        [] ->
          query

        pages ->
          Query.put_filter(query, "visit:entry_page", {:member, Enum.map(pages, & &1[:page])})
      end

    if !Keyword.get(opts, :skip_tracing), do: trace(new_query, property, metrics)

    if Enum.any?(event_metrics) && Enum.empty?(event_result) do
      []
    else
      {limit, _page} = pagination

      session_result =
        breakdown_sessions(site, new_query, "visit:entry_page", session_metrics)
        |> paginate_and_execute(session_metrics, {limit, 1})
        |> transform_keys(%{entry_page: :page})

      metrics = metrics ++ [:page]

      zip_results(
        event_result,
        session_result,
        :page,
        metrics
      )
      |> Enum.map(&Map.take(&1, metrics))
    end
  end

  def breakdown(site, query, "event:name" = property, metrics, pagination, opts) do
    if !Keyword.get(opts, :skip_tracing), do: trace(query, property, metrics)

    breakdown_events(site, query, property, metrics)
    |> paginate_and_execute(metrics, pagination)
  end

  def breakdown(site, query, property, metrics, pagination, opts) do
    query = maybe_update_breakdown_filters(property, query)
    if !Keyword.get(opts, :skip_tracing), do: trace(query, property, metrics)

    metrics_to_select = Util.maybe_add_visitors_metric(metrics) -- @computed_metrics

    case breakdown_table(query, metrics, property) do
      :session ->
        breakdown_sessions(site, query, property, metrics_to_select)
        |> maybe_add_group_conversion_rate(&breakdown_sessions/4, site, query, property, metrics)
        |> paginate_and_execute(metrics, pagination)

      :event ->
        breakdown_events(site, query, property, metrics_to_select)
        |> maybe_add_group_conversion_rate(&breakdown_events/4, site, query, property, metrics)
        |> paginate_and_execute(metrics, pagination)
    end
  end

  defp maybe_update_breakdown_filters(visit_entry_prop, query)
       when visit_entry_prop in [
              "visit:source",
              "visit:entry_page",
              "visit:utm_medium",
              "visit:utm_source",
              "visit:utm_campaign",
              "visit:utm_content",
              "visit:utm_term",
              "visit:entry_page",
              "visit:referrer"
            ] do
    update_hostname(query, "visit:entry_page_hostname")
  end

  defp maybe_update_breakdown_filters("visit:exit_page", query) do
    update_hostname(query, "visit:exit_page_hostname")
  end

  defp maybe_update_breakdown_filters(_, query) do
    query
  end

  defp update_hostname(query, visit_prop) do
    case query.filters["event:hostname"] do
      nil ->
        query

      some ->
        Plausible.Stats.Query.put_filter(query, visit_prop, some)
    end
  end

  # Backwards compatibility
  defp breakdown_table(%Query{experimental_reduced_joins?: false}, _, _), do: :session

  defp breakdown_table(_query, _metrics, "visit:entry_page"), do: :session
  defp breakdown_table(_query, _metrics, "visit:entry_page_hostname"), do: :session
  defp breakdown_table(_query, _metrics, "visit:exit_page"), do: :session
  defp breakdown_table(_query, _metrics, "visit:exit_page_hostname"), do: :session

  defp breakdown_table(query, metrics, property) do
    {_, session_metrics, _} = TableDecider.partition_metrics(metrics, query, property)

    if not Enum.empty?(session_metrics) do
      :session
    else
      :event
    end
  end

  defp zip_results(event_result, session_result, property, metrics) do
    null_row = Enum.map(metrics, fn metric -> {metric, nil} end) |> Enum.into(%{})

    prop_values =
      Enum.map(event_result ++ session_result, fn row -> row[property] end)
      |> Enum.uniq()

    Enum.map(prop_values, fn value ->
      event_row = Enum.find(event_result, fn row -> row[property] == value end) || %{}
      session_row = Enum.find(session_result, fn row -> row[property] == value end) || %{}

      null_row
      |> Map.merge(event_row)
      |> Map.merge(session_row)
    end)
    |> sort_results(metrics)
  end

  defp breakdown_sessions(site, query, property, metrics) do
    from(s in query_sessions(site, query),
      order_by: [desc: fragment("uniq(?)", s.user_id)],
      select: ^select_session_metrics(metrics, query)
    )
    |> filter_converted_sessions(site, query)
    |> do_group_by(property)
    |> merge_imported(site, query, property, metrics)
    |> add_percentage_metric(site, query, metrics)
  end

  defp breakdown_events(site, query, property, metrics) do
    from(e in base_event_query(site, query),
      order_by: [desc: fragment("uniq(?)", e.user_id)],
      select: %{}
    )
    |> do_group_by(property)
    |> select_merge(^select_event_metrics(metrics))
    |> merge_imported(site, query, property, metrics)
    |> add_percentage_metric(site, query, metrics)
  end

  defp paginate_and_execute(_, [], _), do: []

  defp paginate_and_execute(q, metrics, pagination) do
    q
    |> apply_pagination(pagination)
    |> ClickhouseRepo.all(debug_label: :paginate_and_execute)
    |> transform_keys(%{operating_system: :os})
    |> Util.keep_requested_metrics(metrics)
  end

  defp maybe_add_time_on_page(event_results, site, query, metrics) do
    if :time_on_page in metrics do
      pages = Enum.map(event_results, & &1[:page])
      time_on_page_result = breakdown_time_on_page(site, query, pages)

      Enum.map(event_results, fn row ->
        Map.put(row, :time_on_page, time_on_page_result[row[:page]])
      end)
    else
      event_results
    end
  end

  defp breakdown_time_on_page(_site, _query, []) do
    %{}
  end

  defp breakdown_time_on_page(site, query, pages) do
    import Ecto.Query

    windowed_pages_q =
      from e in base_event_query(site, Query.remove_event_filters(query, [:page, :props])),
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

    timed_pages_q =
      if query.include_imported do
        # Imported page views have pre-calculated values
        imported_timed_pages_q =
          from i in "imported_pages",
            group_by: i.page,
            where: i.site_id == ^site.id,
            where: i.date >= ^query.date_range.first and i.date <= ^query.date_range.last,
            where: i.page in ^pages,
            select: %{
              page: i.page,
              time_on_page: sum(i.time_on_page),
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
    |> Plausible.ClickhouseRepo.all(debug_label: :breakdown_time_on_page)
    |> Map.new()
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events" <> _, _}}} = q,
         "event:props:" <> prop
       ) do
    from(
      e in q,
      select_merge: %{
        breakdown_prop_value:
          selected_as(
            fragment(
              "if(not empty(?), ?, '(none)')",
              get_by_key(e, :meta, ^prop),
              get_by_key(e, :meta, ^prop)
            ),
            :breakdown_prop_value
          )
      },
      group_by: selected_as(:breakdown_prop_value),
      order_by: {:asc, selected_as(:breakdown_prop_value)}
    )
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events" <> _, _}}} = q,
         "event:name"
       ) do
    from(
      e in q,
      group_by: e.name,
      select_merge: %{name: e.name},
      order_by: {:asc, e.name}
    )
  end

  defp do_group_by(
         %Ecto.Query{from: %Ecto.Query.FromExpr{source: {"events" <> _, _}}} = q,
         "event:page"
       ) do
    from(
      e in q,
      group_by: e.pathname,
      select_merge: %{page: e.pathname},
      order_by: {:asc, e.pathname}
    )
  end

  defp do_group_by(q, "visit:source") do
    from(
      s in q,
      group_by: s.referrer_source,
      select_merge: %{
        source: fragment("if(empty(?), ?, ?)", s.referrer_source, @no_ref, s.referrer_source)
      },
      order_by: {:asc, s.referrer_source}
    )
  end

  defp do_group_by(q, "visit:country") do
    from(
      s in q,
      where: s.country_code != "\0\0" and s.country_code != "ZZ",
      group_by: s.country_code,
      select_merge: %{country: s.country_code},
      order_by: {:asc, s.country_code}
    )
  end

  defp do_group_by(q, "visit:region") do
    from(
      s in q,
      where: s.subdivision1_code != "",
      group_by: s.subdivision1_code,
      select_merge: %{region: s.subdivision1_code},
      order_by: {:asc, s.subdivision1_code}
    )
  end

  defp do_group_by(q, "visit:city") do
    from(
      s in q,
      where: s.city_geoname_id != 0,
      group_by: s.city_geoname_id,
      select_merge: %{city: s.city_geoname_id},
      order_by: {:asc, s.city_geoname_id}
    )
  end

  defp do_group_by(q, "visit:entry_page") do
    from(
      s in q,
      # Sessions without pageviews don't get entry_page assigned, hence they should get ignored
      where: s.entry_page != "",
      group_by: s.entry_page,
      select_merge: %{entry_page: s.entry_page},
      order_by: {:asc, s.entry_page}
    )
  end

  defp do_group_by(q, "visit:exit_page") do
    from(
      s in q,
      # Sessions without pageviews don't get entry_page assigned, hence they should get ignored
      where: s.entry_page != "",
      group_by: s.exit_page,
      select_merge: %{exit_page: s.exit_page},
      order_by: {:asc, s.exit_page}
    )
  end

  defp do_group_by(q, "visit:referrer") do
    from(
      s in q,
      group_by: s.referrer,
      select_merge: %{
        referrer: fragment("if(empty(?), ?, ?)", s.referrer, @no_ref, s.referrer)
      },
      order_by: {:asc, s.referrer}
    )
  end

  defp do_group_by(q, "visit:utm_medium") do
    from(
      s in q,
      where: fragment("not empty(?)", s.utm_medium),
      group_by: s.utm_medium,
      select_merge: %{
        utm_medium: s.utm_medium
      }
    )
  end

  defp do_group_by(q, "visit:utm_source") do
    from(
      s in q,
      where: fragment("not empty(?)", s.utm_source),
      group_by: s.utm_source,
      select_merge: %{
        utm_source: s.utm_source
      }
    )
  end

  defp do_group_by(q, "visit:utm_campaign") do
    from(
      s in q,
      where: fragment("not empty(?)", s.utm_campaign),
      group_by: s.utm_campaign,
      select_merge: %{
        utm_campaign: s.utm_campaign
      }
    )
  end

  defp do_group_by(q, "visit:utm_content") do
    from(
      s in q,
      where: fragment("not empty(?)", s.utm_content),
      group_by: s.utm_content,
      select_merge: %{
        utm_content: s.utm_content
      }
    )
  end

  defp do_group_by(q, "visit:utm_term") do
    from(
      s in q,
      where: fragment("not empty(?)", s.utm_term),
      group_by: s.utm_term,
      select_merge: %{
        utm_term: s.utm_term
      }
    )
  end

  defp do_group_by(q, "visit:device") do
    from(
      s in q,
      group_by: s.screen_size,
      select_merge: %{
        device: fragment("if(empty(?), ?, ?)", s.screen_size, @not_set, s.screen_size)
      },
      order_by: {:asc, s.screen_size}
    )
  end

  defp do_group_by(q, "visit:os") do
    from(
      s in q,
      group_by: s.operating_system,
      select_merge: %{
        operating_system:
          fragment("if(empty(?), ?, ?)", s.operating_system, @not_set, s.operating_system)
      },
      order_by: {:asc, s.operating_system}
    )
  end

  defp do_group_by(q, "visit:os_version") do
    from(
      s in q,
      group_by: [s.operating_system, s.operating_system_version],
      select_merge: %{
        os: fragment("if(empty(?), ?, ?)", s.operating_system, @not_set, s.operating_system),
        os_version:
          fragment(
            "if(empty(?), ?, ?)",
            s.operating_system_version,
            @not_set,
            s.operating_system_version
          )
      },
      order_by: {:asc, s.operating_system_version}
    )
  end

  defp do_group_by(q, "visit:browser") do
    from(
      s in q,
      group_by: s.browser,
      select_merge: %{
        browser: fragment("if(empty(?), ?, ?)", s.browser, @not_set, s.browser)
      },
      order_by: {:asc, s.browser}
    )
  end

  defp do_group_by(q, "visit:browser_version") do
    from(
      s in q,
      group_by: [s.browser, s.browser_version],
      select_merge: %{
        browser: fragment("if(empty(?), ?, ?)", s.browser, @not_set, s.browser),
        browser_version:
          fragment("if(empty(?), ?, ?)", s.browser_version, @not_set, s.browser_version)
      },
      order_by: {:asc, s.browser_version}
    )
  end

  defp group_by_field_names("event:props:" <> _prop), do: [:name]
  defp group_by_field_names("visit:os"), do: [:operating_system]
  defp group_by_field_names("visit:os_version"), do: [:os, :os_version]
  defp group_by_field_names("visit:browser_version"), do: [:browser, :browser_version]

  defp group_by_field_names(property), do: [Plausible.Stats.Filters.without_prefix(property)]

  defp on_matches_group_by(fields) do
    Enum.reduce(fields, nil, &fields_equal/2)
  end

  defp outer_order_by(fields) do
    Enum.map(fields, fn field_name -> {:asc, dynamic([q], field(q, ^field_name))} end)
  end

  defp fields_equal(field_name, nil),
    do: dynamic([a, b], field(a, ^field_name) == field(b, ^field_name))

  defp fields_equal(field_name, condition),
    do: dynamic([a, b], field(a, ^field_name) == field(b, ^field_name) and ^condition)

  defp sort_results(results, metrics) do
    Enum.sort_by(
      results,
      fn entry ->
        case entry[sorting_key(metrics)] do
          nil -> 0
          n -> n
        end
      end,
      :desc
    )
  end

  # This function injects a conversion_rate metric into
  # a breakdown query. It is calculated as X / Y, where:
  #
  #   * X is the number of conversions for a breakdown
  #     result (conversion = number of visitors who
  #     completed the filtered goal with the filtered
  #     custom properties).
  #
  #  * Y is the number of all visitors for this breakdown
  #    result without the `event:goal` and `event:props:*`
  #    filters.
  defp maybe_add_group_conversion_rate(q, breakdown_fn, site, query, property, metrics) do
    if :conversion_rate in metrics do
      breakdown_total_visitors_query = query |> Query.remove_event_filters([:goal, :props])

      breakdown_total_visitors_q =
        breakdown_fn.(site, breakdown_total_visitors_query, property, [:visitors])

      from(e in subquery(q),
        left_join: c in subquery(breakdown_total_visitors_q),
        on: ^on_matches_group_by(group_by_field_names(property)),
        select_merge: %{
          total_visitors: c.visitors,
          conversion_rate:
            fragment(
              "if(? > 0, round(? / ? * 100, 1), 0)",
              c.visitors,
              e.visitors,
              c.visitors
            )
        },
        order_by: [desc: e.visitors],
        order_by: ^outer_order_by(group_by_field_names(property))
      )
    else
      q
    end
  end

  # When querying custom event goals and pageviewgoals together, UNION ALL is used
  # so the same fields must be present on both sides of the union. This change to the
  # query will ensure that we don't unnecessarily read revenue column for pageview goals
  defp mark_revenue_as_nil(select_columns) do
    select_columns
    |> Map.replace(:total_revenue, nil)
    |> Map.replace(:average_revenue, nil)
  end

  defp sorting_key(metrics) do
    if Enum.member?(metrics, :visitors), do: :visitors, else: List.first(metrics)
  end

  defp transform_keys(results, keys_to_replace) do
    Enum.map(results, fn map ->
      Enum.map(map, fn {key, val} ->
        {Map.get(keys_to_replace, key, key), val}
      end)
      |> Enum.into(%{})
    end)
  end

  defp apply_pagination(q, {limit, page}) do
    offset = (page - 1) * limit

    q
    |> limit(^limit)
    |> offset(^offset)
  end

  defp trace(query, property, metrics) do
    Query.trace(query, metrics)

    Tracer.set_attributes([
      {"plausible.query.breakdown_property", property}
    ])
  end

  on_full_build do
    defp cast_revenue_metrics_to_money(results, revenue_goals) do
      Plausible.Stats.Goal.Revenue.cast_revenue_metrics_to_money(results, revenue_goals)
    end
  else
    defp cast_revenue_metrics_to_money(results, _revenue_goals), do: results
  end
end
