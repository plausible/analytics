defmodule Plausible.Stats.SQL.Expression do
  @moduledoc false

  import Ecto.Query

  use Plausible.Stats.Fragments

  @no_ref "Direct / None"
  @not_set "(not set)"

  defmacrop field_or_blank_value(expr, empty_value) do
    quote do
      dynamic(
        [t],
        fragment("if(empty(?), ?, ?)", unquote(expr), unquote(empty_value), unquote(expr))
      )
    end
  end

  def dimension("time:hour", query) do
    dynamic([t], fragment("toStartOfHour(toTimeZone(?, ?))", t.timestamp, ^query.timezone))
  end

  def dimension("time:day", query) do
    dynamic([t], fragment("toDate(toTimeZone(?, ?))", t.timestamp, ^query.timezone))
  end

  def dimension("time:month", query) do
    dynamic([t], fragment("toStartOfMonth(toTimeZone(?, ?))", t.timestamp, ^query.timezone))
  end

  def dimension("event:name", _query), do: dynamic([t], t.name)
  def dimension("event:page", _query), do: dynamic([t], t.pathname)
  def dimension("event:hostname", _query), do: dynamic([t], t.hostname)

  def dimension("event:props:" <> property_name, _query) do
    dynamic(
      [t],
      fragment(
        "if(not empty(?), ?, '(none)')",
        get_by_key(t, :meta, ^property_name),
        get_by_key(t, :meta, ^property_name)
      )
    )
  end

  def dimension("visit:entry_page", _query), do: dynamic([t], t.entry_page)
  def dimension("visit:exit_page", _query), do: dynamic([t], t.exit_page)

  def dimension("visit:utm_medium", _query),
    do: field_or_blank_value(t.utm_medium, @not_set)

  def dimension("visit:utm_source", _query),
    do: field_or_blank_value(t.utm_source, @not_set)

  def dimension("visit:utm_campaign", _query),
    do: field_or_blank_value(t.utm_campaign, @not_set)

  def dimension("visit:utm_content", _query),
    do: field_or_blank_value(t.utm_content, @not_set)

  def dimension("visit:utm_term", _query),
    do: field_or_blank_value(t.utm_term, @not_set)

  def dimension("visit:source", _query),
    do: field_or_blank_value(t.source, @no_ref)

  def dimension("visit:referrer", _query),
    do: field_or_blank_value(t.referrer, @no_ref)

  def dimension("visit:device", _query),
    do: field_or_blank_value(t.device, @not_set)

  def dimension("visit:os", _query), do: field_or_blank_value(t.os, @not_set)

  def dimension("visit:os_version", _query),
    do: field_or_blank_value(t.os_version, @not_set)

  def dimension("visit:browser", _query),
    do: field_or_blank_value(t.browser, @not_set)

  def dimension("visit:browser_version", _query),
    do: field_or_blank_value(t.browser_version, @not_set)

  # :TODO: Locations also set extra filters
  def dimension("visit:country", _query), do: dynamic([t], t.country)
  def dimension("visit:region", _query), do: dynamic([t], t.region)
  def dimension("visit:city", _query), do: dynamic([t], t.city)
end
