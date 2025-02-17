defmodule Plausible.Stats.SQL.Expression do
  @moduledoc """
  This module is responsible for generating SQL/Ecto expressions
  for dimensions and metrics used in query SELECT statement.

  Each dimension and metric is tagged with with selected_as for easier
  usage down the line.
  """

  use Plausible
  use Plausible.Stats.SQL.Fragments

  import Ecto.Query

  alias Plausible.Stats.{Query, Filters, SQL}

  @no_ref "Direct / None"
  @no_channel "Direct"
  @not_set "(not set)"

  defmacrop field_or_blank_value(q, key, expr, empty_value) do
    quote do
      select_merge_as(unquote(q), [t], %{
        unquote(key) =>
          fragment("if(empty(?), ?, ?)", unquote(expr), unquote(empty_value), unquote(expr))
      })
    end
  end

  defmacrop time_slots(query, period_in_seconds) do
    quote do
      fragment(
        "timeSlots(toTimeZone(?, ?), toUInt32(timeDiff(?, ?)), toUInt32(?))",
        s.start,
        ^unquote(query).timezone,
        s.start,
        s.timestamp,
        ^unquote(period_in_seconds)
      )
    end
  end

  def select_dimension(q, key, "time:month", _table, query) do
    select_merge_as(q, [t], %{
      key => fragment("toStartOfMonth(toTimeZone(?, ?))", t.timestamp, ^query.timezone)
    })
  end

  def select_dimension(q, key, "time:week", _table, query) do
    date_range = Query.date_range(query)

    select_merge_as(q, [t], %{
      key =>
        weekstart_not_before(
          to_timezone(t.timestamp, ^query.timezone),
          ^date_range.first
        )
    })
  end

  def select_dimension(q, key, "time:day", _table, query) do
    select_merge_as(q, [t], %{
      key => fragment("toDate(toTimeZone(?, ?))", t.timestamp, ^query.timezone)
    })
  end

  def select_dimension(q, key, "time:hour", :sessions, query) do
    # :TRICKY: ClickHouse timeSlots works off of unix epoch and is not
    #   timezone-aware. This means that for e.g. Asia/Katmandu (GMT+5:45)
    #   to work, we divide time into 15-minute buckets and later combine these
    #   via toStartOfHour
    q
    |> join(:inner, [s], time_slot in time_slots(query, 15 * 60),
      as: :time_slot,
      hints: "ARRAY",
      on: true
    )
    |> select_merge_as([s, time_slot: time_slot], %{
      key => fragment("toStartOfHour(?)", time_slot)
    })
  end

  def select_dimension(q, key, "time:hour", _table, query) do
    select_merge_as(q, [t], %{
      key => fragment("toStartOfHour(toTimeZone(?, ?))", t.timestamp, ^query.timezone)
    })
  end

  # :NOTE: This is not exposed in Query APIv2
  def select_dimension(q, key, "time:minute", :sessions, query) do
    q
    |> join(:inner, [s], time_slot in time_slots(query, 60),
      as: :time_slot,
      hints: "ARRAY",
      on: true
    )
    |> select_merge_as([s, time_slot: time_slot], %{
      key => fragment("?", time_slot)
    })
  end

  # :NOTE: This is not exposed in Query APIv2
  def select_dimension(q, key, "time:minute", _table, query) do
    select_merge_as(q, [t], %{
      key => fragment("toStartOfMinute(toTimeZone(?, ?))", t.timestamp, ^query.timezone)
    })
  end

  def select_dimension(q, key, "event:name", _table, _query),
    do: select_merge_as(q, [t], %{key => t.name})

  def select_dimension(q, key, "event:page", _table, _query),
    do: select_merge_as(q, [t], %{key => t.pathname})

  def select_dimension(q, key, "event:hostname", _table, _query),
    do: select_merge_as(q, [t], %{key => t.hostname})

  def select_dimension(q, key, "event:props:" <> property_name, _table, _query) do
    select_merge_as(q, [t], %{
      key =>
        fragment(
          "if(not empty(?), ?, '(none)')",
          get_by_key(t, :meta, ^property_name),
          get_by_key(t, :meta, ^property_name)
        )
    })
  end

  def select_dimension(q, key, "visit:entry_page", _table, _query),
    do: select_merge_as(q, [t], %{key => t.entry_page})

  def select_dimension(q, key, "visit:exit_page", _table, _query),
    do: select_merge_as(q, [t], %{key => t.exit_page})

  def select_dimension(q, key, "visit:utm_medium", _table, _query),
    do: field_or_blank_value(q, key, t.utm_medium, @not_set)

  def select_dimension(q, key, "visit:utm_source", _table, _query),
    do: field_or_blank_value(q, key, t.utm_source, @not_set)

  def select_dimension(q, key, "visit:utm_campaign", _table, _query),
    do: field_or_blank_value(q, key, t.utm_campaign, @not_set)

  def select_dimension(q, key, "visit:utm_content", _table, _query),
    do: field_or_blank_value(q, key, t.utm_content, @not_set)

  def select_dimension(q, key, "visit:utm_term", _table, _query),
    do: field_or_blank_value(q, key, t.utm_term, @not_set)

  def select_dimension(q, key, "visit:source", _table, _query),
    do: field_or_blank_value(q, key, t.source, @no_ref)

  def select_dimension(q, key, "visit:channel", _table, _query),
    do: field_or_blank_value(q, key, t.acquisition_channel, @no_channel)

  def select_dimension(q, key, "visit:referrer", _table, _query),
    do: field_or_blank_value(q, key, t.referrer, @no_ref)

  def select_dimension(q, key, "visit:device", _table, _query),
    do: field_or_blank_value(q, key, t.device, @not_set)

  def select_dimension(q, key, "visit:os", _table, _query),
    do: field_or_blank_value(q, key, t.os, @not_set)

  def select_dimension(q, key, "visit:os_version", _table, _query),
    do: field_or_blank_value(q, key, t.os_version, @not_set)

  def select_dimension(q, key, "visit:browser", _table, _query),
    do: field_or_blank_value(q, key, t.browser, @not_set)

  def select_dimension(q, key, "visit:browser_version", _table, _query),
    do: field_or_blank_value(q, key, t.browser_version, @not_set)

  def select_dimension(q, key, "visit:country", _table, _query),
    do: select_merge_as(q, [t], %{key => t.country})

  def select_dimension(q, key, "visit:region", _table, _query),
    do: select_merge_as(q, [t], %{key => t.region})

  def select_dimension(q, key, "visit:city", _table, _query),
    do: select_merge_as(q, [t], %{key => t.city})

  def select_dimension(q, key, "visit:country_name", _table, _query),
    do: select_merge_as(q, [t], %{key => t.country_name})

  def select_dimension(q, key, "visit:region_name", _table, _query),
    do: select_merge_as(q, [t], %{key => t.region_name})

  def select_dimension(q, key, "visit:city_name", _table, _query),
    do: select_merge_as(q, [t], %{key => t.city_name})

  def event_metric(:pageviews) do
    wrap_alias([e], %{
      pageviews:
        fragment("toUInt64(round(countIf(? = 'pageview') * any(_sample_factor)))", e.name)
    })
  end

  def event_metric(:events) do
    wrap_alias([e], %{
      events:
        fragment("toUInt64(round(countIf(? != 'engagement') * any(_sample_factor)))", e.name)
    })
  end

  def event_metric(:visitors) do
    wrap_alias([e], %{
      visitors: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", e.user_id)
    })
  end

  def event_metric(:visits) do
    wrap_alias([e], %{
      visits: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", e.session_id)
    })
  end

  on_ee do
    def event_metric(:total_revenue) do
      wrap_alias(
        [e],
        %{
          total_revenue:
            fragment("toDecimal64(sum(?) * any(_sample_factor), 3)", e.revenue_reporting_amount)
        }
      )
    end

    def event_metric(:average_revenue) do
      wrap_alias(
        [e],
        %{
          average_revenue:
            fragment("toDecimal64(avg(?) * any(_sample_factor), 3)", e.revenue_reporting_amount)
        }
      )
    end
  end

  def event_metric(:sample_percent) do
    wrap_alias([], %{
      sample_percent:
        fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
    })
  end

  def event_metric(:percentage), do: %{}
  def event_metric(:conversion_rate), do: %{}
  def event_metric(:scroll_depth), do: %{}
  def event_metric(:group_conversion_rate), do: %{}
  def event_metric(:total_visitors), do: %{}

  def event_metric(unknown), do: raise("Unknown metric: #{unknown}")

  def session_metric(:bounce_rate, query) do
    # :TRICKY: If page is passed to query, we only count bounce rate where users _entered_ at page.
    event_page_filter = Filters.get_toplevel_filter(query, "event:page")
    condition = SQL.WhereBuilder.build_condition(:entry_page, event_page_filter)

    wrap_alias([], %{
      bounce_rate:
        fragment(
          # :TRICKY: Before PR #4493, we could have sessions where `sum(is_bounce * sign)`
          # is negative, leading to an underflow and >100% bounce rate. This works around
          # that issue.
          "toUInt32(greatest(ifNotFinite(round(sumIf(is_bounce * sign, ?) / sumIf(sign, ?) * 100), 0), 0))",
          ^condition,
          ^condition
        ),
      __internal_visits: fragment("toUInt32(sum(sign))")
    })
  end

  def session_metric(:visits, _query) do
    wrap_alias([s], %{
      visits: fragment("toUInt64(round(sum(?) * any(_sample_factor)))", s.sign)
    })
  end

  def session_metric(:pageviews, _query) do
    wrap_alias([s], %{
      pageviews:
        fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.pageviews)
    })
  end

  def session_metric(:events, _query) do
    wrap_alias([s], %{
      events: fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.events)
    })
  end

  def session_metric(:visitors, _query) do
    wrap_alias([s], %{
      visitors: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", s.user_id)
    })
  end

  def session_metric(:visit_duration, _query) do
    wrap_alias([], %{
      visit_duration:
        fragment("toUInt32(ifNotFinite(round(sum(duration * sign) / sum(sign)), 0))"),
      __internal_visits: fragment("toUInt32(sum(sign))")
    })
  end

  def session_metric(:views_per_visit, _query) do
    wrap_alias([s], %{
      views_per_visit:
        fragment(
          "ifNotFinite(round(sum(? * ?) / sum(?), 2), 0)",
          s.sign,
          s.pageviews,
          s.sign
        ),
      __internal_visits: fragment("toUInt32(sum(sign))")
    })
  end

  def session_metric(:sample_percent, _query) do
    wrap_alias([], %{
      sample_percent:
        fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
    })
  end

  def session_metric(:percentage, _query), do: %{}
  def session_metric(:conversion_rate, _query), do: %{}
  def session_metric(:group_conversion_rate, _query), do: %{}

  defmacro event_goal_join(goal_join_data) do
    quote do
      fragment(
        """
        arrayIntersect(
          multiMatchAllIndices(?, ?),
          arrayMap(
            (expected_name, threshold, index) -> if(expected_name = ? and ? between threshold and 100, index, -1),
            ?,
            ?,
            ?
          )
        )
        """,
        e.pathname,
        type(^unquote(goal_join_data).page_regexes, {:array, :string}),
        e.name,
        e.scroll_depth,
        type(^unquote(goal_join_data).event_names_by_type, {:array, :string}),
        type(^unquote(goal_join_data).scroll_thresholds, {:array, :integer}),
        type(^unquote(goal_join_data).indices, {:array, :integer})
      )
    end
  end
end
