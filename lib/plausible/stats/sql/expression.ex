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

  alias Plausible.Stats.{Query, Filters}

  @no_ref "Direct / None"
  @not_set "(not set)"

  defmacrop field_or_blank_value(key, expr, empty_value) do
    quote do
      wrap_select_columns([t], %{
        unquote(key) =>
          fragment("if(empty(?), ?, ?)", unquote(expr), unquote(empty_value), unquote(expr))
      })
    end
  end

  def dimension(key, "time:hour", query) do
    wrap_select_columns([t], %{
      key => fragment("toStartOfHour(toTimeZone(?, ?))", t.timestamp, ^query.timezone)
    })
  end

  def dimension(key, "time:day", query) do
    wrap_select_columns([t], %{
      key => fragment("toDate(toTimeZone(?, ?))", t.timestamp, ^query.timezone)
    })
  end

  def dimension(key, "time:month", query) do
    wrap_select_columns([t], %{
      key => fragment("toStartOfMonth(toTimeZone(?, ?))", t.timestamp, ^query.timezone)
    })
  end

  def dimension(key, "event:name", _query),
    do: wrap_select_columns([t], %{key => t.name})

  def dimension(key, "event:page", _query),
    do: wrap_select_columns([t], %{key => t.pathname})

  def dimension(key, "event:hostname", _query),
    do: wrap_select_columns([t], %{key => t.hostname})

  def dimension(key, "event:props:" <> property_name, _query) do
    wrap_select_columns([t], %{
      key =>
        fragment(
          "if(not empty(?), ?, '(none)')",
          get_by_key(t, :meta, ^property_name),
          get_by_key(t, :meta, ^property_name)
        )
    })
  end

  def dimension(key, "visit:entry_page", _query),
    do: wrap_select_columns([t], %{key => t.entry_page})

  def dimension(key, "visit:exit_page", _query),
    do: wrap_select_columns([t], %{key => t.exit_page})

  def dimension(key, "visit:utm_medium", _query),
    do: field_or_blank_value(key, t.utm_medium, @not_set)

  def dimension(key, "visit:utm_source", _query),
    do: field_or_blank_value(key, t.utm_source, @not_set)

  def dimension(key, "visit:utm_campaign", _query),
    do: field_or_blank_value(key, t.utm_campaign, @not_set)

  def dimension(key, "visit:utm_content", _query),
    do: field_or_blank_value(key, t.utm_content, @not_set)

  def dimension(key, "visit:utm_term", _query),
    do: field_or_blank_value(key, t.utm_term, @not_set)

  def dimension(key, "visit:source", _query),
    do: field_or_blank_value(key, t.source, @no_ref)

  def dimension(key, "visit:referrer", _query),
    do: field_or_blank_value(key, t.referrer, @no_ref)

  def dimension(key, "visit:device", _query),
    do: field_or_blank_value(key, t.device, @not_set)

  def dimension(key, "visit:os", _query),
    do: field_or_blank_value(key, t.os, @not_set)

  def dimension(key, "visit:os_version", _query),
    do: field_or_blank_value(key, t.os_version, @not_set)

  def dimension(key, "visit:browser", _query),
    do: field_or_blank_value(key, t.browser, @not_set)

  def dimension(key, "visit:browser_version", _query),
    do: field_or_blank_value(key, t.browser_version, @not_set)

  def dimension(key, "visit:country", _query),
    do: wrap_select_columns([t], %{key => t.country})

  def dimension(key, "visit:region", _query),
    do: wrap_select_columns([t], %{key => t.region})

  def dimension(key, "visit:city", _query),
    do: wrap_select_columns([t], %{key => t.city})

  def event_metric(:pageviews) do
    wrap_select_columns([e], %{
      pageviews:
        fragment("toUInt64(round(countIf(? = 'pageview') * any(_sample_factor)))", e.name)
    })
  end

  def event_metric(:events) do
    wrap_select_columns([], %{
      events: fragment("toUInt64(round(count(*) * any(_sample_factor)))")
    })
  end

  def event_metric(:visitors) do
    wrap_select_columns([e], %{
      visitors: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", e.user_id)
    })
  end

  def event_metric(:visits) do
    wrap_select_columns([e], %{
      visits: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", e.session_id)
    })
  end

  on_ee do
    def event_metric(:total_revenue) do
      wrap_select_columns(
        [e],
        %{
          total_revenue:
            fragment("toDecimal64(sum(?) * any(_sample_factor), 3)", e.revenue_reporting_amount)
        }
      )
    end

    def event_metric(:average_revenue) do
      wrap_select_columns(
        [e],
        %{
          average_revenue:
            fragment("toDecimal64(avg(?) * any(_sample_factor), 3)", e.revenue_reporting_amount)
        }
      )
    end
  end

  def event_metric(:sample_percent) do
    wrap_select_columns([], %{
      sample_percent:
        fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
    })
  end

  def event_metric(:percentage), do: %{}
  def event_metric(:conversion_rate), do: %{}
  def event_metric(:group_conversion_rate), do: %{}
  def event_metric(:total_visitors), do: %{}

  def event_metric(unknown), do: raise("Unknown metric: #{unknown}")

  def session_metric(:bounce_rate, query) do
    # :TRICKY: If page is passed to query, we only count bounce rate where users _entered_ at page.
    event_page_filter = Query.get_filter(query, "event:page")
    condition = Filters.WhereBuilder.build_condition(:entry_page, event_page_filter)

    wrap_select_columns([], %{
      bounce_rate:
        fragment(
          "toUInt32(ifNotFinite(round(sumIf(is_bounce * sign, ?) / sumIf(sign, ?) * 100), 0))",
          ^condition,
          ^condition
        ),
      __internal_visits: fragment("toUInt32(sum(sign))")
    })
  end

  def session_metric(:visits, _query) do
    wrap_select_columns([s], %{
      visits: fragment("toUInt64(round(sum(?) * any(_sample_factor)))", s.sign)
    })
  end

  def session_metric(:pageviews, _query) do
    wrap_select_columns([s], %{
      pageviews:
        fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.pageviews)
    })
  end

  def session_metric(:events, _query) do
    wrap_select_columns([s], %{
      events: fragment("toUInt64(round(sum(? * ?) * any(_sample_factor)))", s.sign, s.events)
    })
  end

  def session_metric(:visitors, _query) do
    wrap_select_columns([s], %{
      visitors: fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", s.user_id)
    })
  end

  def session_metric(:visit_duration, _query) do
    wrap_select_columns([], %{
      visit_duration:
        fragment("toUInt32(ifNotFinite(round(sum(duration * sign) / sum(sign)), 0))"),
      __internal_visits: fragment("toUInt32(sum(sign))")
    })
  end

  def session_metric(:views_per_visit, _query) do
    wrap_select_columns([s], %{
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
    wrap_select_columns([], %{
      sample_percent:
        fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
    })
  end

  def session_metric(:percentage, _query), do: %{}
  def session_metric(:conversion_rate, _query), do: %{}
  def session_metric(:group_conversion_rate, _query), do: %{}

  defmacro event_goal_join(events, page_regexes) do
    quote do
      fragment(
        """
        arrayPushFront(
          CAST(multiMatchAllIndices(?, ?) AS Array(Int64)),
          -indexOf(?, ?)
        )
        """,
        e.pathname,
        type(^unquote(page_regexes), {:array, :string}),
        type(^unquote(events), {:array, :string}),
        e.name
      )
    end
  end
end
