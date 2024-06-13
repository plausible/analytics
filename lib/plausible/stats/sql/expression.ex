defmodule Plausible.Stats.SQL.Expression do
  @moduledoc false

  import Ecto.Query

  use Plausible.Stats.Fragments

  @no_ref "Direct / None"
  @not_set "(not set)"

  defmacrop field_or_blank_value(expr, mode, empty_value) do
    quote do
      case unquote(mode) do
        :label ->
          dynamic(
            [t],
            fragment("if(empty(?), ?, ?)", unquote(expr), unquote(empty_value), unquote(expr))
          )

        _ ->
          dynamic([t], unquote(expr))
      end
    end
  end

  def dimension("time:hour", query, _mode) do
    dynamic([t], fragment("toStartOfHour(toTimeZone(?, ?))", t.timestamp, ^query.timezone))
  end

  def dimension("time:day", query, _mode) do
    dynamic([t], fragment("toDate(toTimeZone(?, ?))", t.timestamp, ^query.timezone))
  end

  def dimension("time:month", query, _mode) do
    dynamic([t], fragment("toStartOfMonth(toTimeZone(?, ?))", t.timestamp, ^query.timezone))
  end

  def dimension("event:name", _query, _mode), do: dynamic([t], t.name)
  def dimension("event:page", _query, _mode), do: dynamic([t], t.pathname)
  def dimension("event:hostname", _query, _mode), do: dynamic([t], t.hostname)

  def dimension("event:props:" <> property_name, _query, _mode) do
    dynamic(
      [t],
      fragment(
        "if(not empty(?), ?, '(none)')",
        get_by_key(t, :meta, ^property_name),
        get_by_key(t, :meta, ^property_name)
      )
    )
  end

  def dimension("visit:entry_page", _query, _mode), do: dynamic([t], t.entry_page)
  def dimension("visit:exit_page", _query, _mode), do: dynamic([t], t.exit_page)

  def dimension("visit:utm_medium", _query, mode),
    do: field_or_blank_value(t.utm_medium, mode, @not_set)

  def dimension("visit:utm_source", _query, mode),
    do: field_or_blank_value(t.utm_source, mode, @not_set)

  def dimension("visit:utm_campaign", _query, mode),
    do: field_or_blank_value(t.utm_campaign, mode, @not_set)

  def dimension("visit:utm_content", _query, mode),
    do: field_or_blank_value(t.utm_content, mode, @not_set)

  def dimension("visit:utm_term", _query, mode),
    do: field_or_blank_value(t.utm_term, mode, @not_set)

  def dimension("visit:source", _query, mode),
    do: field_or_blank_value(t.source, mode, @no_ref)

  def dimension("visit:referrer", _query, mode),
    do: field_or_blank_value(t.referrer, mode, @no_ref)

  def dimension("visit:device", _query, mode),
    do: field_or_blank_value(t.device, mode, @not_set)

  def dimension("visit:os", _query, mode), do: field_or_blank_value(t.os, mode, @not_set)

  def dimension("visit:os_version", _query, mode),
    do: field_or_blank_value(t.os_version, mode, @not_set)

  def dimension("visit:browser", _query, mode),
    do: field_or_blank_value(t.browser, mode, @not_set)

  def dimension("visit:browser_version", _query, mode),
    do: field_or_blank_value(t.browser_version, mode, @not_set)

  # :TODO: Locations also set extra filters
  def dimension("visit:country", _query, _mode), do: dynamic([t], t.country)
  def dimension("visit:region", _query, _mode), do: dynamic([t], t.region)
  def dimension("visit:city", _query, _mode), do: dynamic([t], t.city)
end
