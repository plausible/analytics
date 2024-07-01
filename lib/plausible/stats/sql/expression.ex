defmodule Plausible.Stats.SQL.Expression do
  @moduledoc """
  This module is responsible for generating SQL/Ecto expressions
  for dimensions used in query select, group_by and order_by.
  """

  import Ecto.Query

  use Plausible.Stats.Fragments

  @no_ref "Direct / None"
  @not_set "(not set)"

  defmacrop field_or_blank_value(expr, empty_value, select_alias) do
    quote do
      dynamic(
        [t],
        selected_as(
          fragment("if(empty(?), ?, ?)", unquote(expr), unquote(empty_value), unquote(expr)),
          ^unquote(select_alias)
        )
      )
    end
  end

  def dimension("time:hour", query, select_alias) do
    dynamic(
      [t],
      selected_as(
        fragment("toStartOfHour(toTimeZone(?, ?))", t.timestamp, ^query.timezone),
        ^select_alias
      )
    )
  end

  def dimension("time:day", query, select_alias) do
    dynamic(
      [t],
      selected_as(
        fragment("toDate(toTimeZone(?, ?))", t.timestamp, ^query.timezone),
        ^select_alias
      )
    )
  end

  def dimension("time:month", query, select_alias) do
    dynamic(
      [t],
      selected_as(
        fragment("toStartOfMonth(toTimeZone(?, ?))", t.timestamp, ^query.timezone),
        ^select_alias
      )
    )
  end

  def dimension("event:name", _query, select_alias),
    do: dynamic([t], selected_as(t.name, ^select_alias))

  def dimension("event:page", _query, select_alias),
    do: dynamic([t], selected_as(t.pathname, ^select_alias))

  def dimension("event:hostname", _query, select_alias),
    do: dynamic([t], selected_as(t.hostname, ^select_alias))

  def dimension("event:props:" <> property_name, _query, select_alias) do
    dynamic(
      [t],
      selected_as(
        fragment(
          "if(not empty(?), ?, '(none)')",
          get_by_key(t, :meta, ^property_name),
          get_by_key(t, :meta, ^property_name)
        ),
        ^select_alias
      )
    )
  end

  def dimension("visit:entry_page", _query, select_alias),
    do: dynamic([t], selected_as(t.entry_page, ^select_alias))

  def dimension("visit:exit_page", _query, select_alias),
    do: dynamic([t], selected_as(t.exit_page, ^select_alias))

  def dimension("visit:utm_medium", _query, select_alias),
    do: field_or_blank_value(t.utm_medium, @not_set, select_alias)

  def dimension("visit:utm_source", _query, select_alias),
    do: field_or_blank_value(t.utm_source, @not_set, select_alias)

  def dimension("visit:utm_campaign", _query, select_alias),
    do: field_or_blank_value(t.utm_campaign, @not_set, select_alias)

  def dimension("visit:utm_content", _query, select_alias),
    do: field_or_blank_value(t.utm_content, @not_set, select_alias)

  def dimension("visit:utm_term", _query, select_alias),
    do: field_or_blank_value(t.utm_term, @not_set, select_alias)

  def dimension("visit:source", _query, select_alias),
    do: field_or_blank_value(t.source, @no_ref, select_alias)

  def dimension("visit:referrer", _query, select_alias),
    do: field_or_blank_value(t.referrer, @no_ref, select_alias)

  def dimension("visit:device", _query, select_alias),
    do: field_or_blank_value(t.device, @not_set, select_alias)

  def dimension("visit:os", _query, select_alias),
    do: field_or_blank_value(t.os, @not_set, select_alias)

  def dimension("visit:os_version", _query, select_alias),
    do: field_or_blank_value(t.os_version, @not_set, select_alias)

  def dimension("visit:browser", _query, select_alias),
    do: field_or_blank_value(t.browser, @not_set, select_alias)

  def dimension("visit:browser_version", _query, select_alias),
    do: field_or_blank_value(t.browser_version, @not_set, select_alias)

  def dimension("visit:country", _query, select_alias),
    do: dynamic([t], selected_as(t.country, ^select_alias))

  def dimension("visit:region", _query, select_alias),
    do: dynamic([t], selected_as(t.region, ^select_alias))

  def dimension("visit:city", _query, select_alias),
    do: dynamic([t], selected_as(t.city, ^select_alias))

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
