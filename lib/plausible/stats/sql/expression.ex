defmodule Plausible.Stats.SQL.Expression do
  @moduledoc """
  This module is responsible for generating SQL/Ecto expressions
  for dimensions used in query select, group_by and order_by.
  """

  import Ecto.Query

  use Plausible.Stats.SQL.Fragments

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
