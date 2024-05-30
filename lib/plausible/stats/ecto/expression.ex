defmodule Plausible.Stats.Ecto.Expression do
  import Ecto.Query

  use Plausible.Stats.Fragments

  @no_ref "Direct / None"
  @not_set "(not set)"

  defmacrop field_or_blank_value(expr, :group_by) do
    quote do
      fragment("if(empty(?), ?, ?)", unquote(expr), @no_ref, unquote(expr))
    end
  end

  defmacrop field_or_blank_value(expr, _), do: expr

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
  def dimension("event:page", _query, _mode), do: dynamic([t], t.page)
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

  def dimension("visit:utm_medium", _query, _mode), do: dynamic([t], t.utm_medium)
  def dimension("visit:utm_source", _query, _mode), do: dynamic([t], t.utm_source)
  def dimension("visit:utm_campaign", _query, _mode), do: dynamic([t], t.utm_campaign)
  def dimension("visit:utm_content", _query, _mode), do: dynamic([t], t.utm_content)
  def dimension("visit:utm_term", _query, _mode), do: dynamic([t], t.utm_term)

  def dimension("visit:source", _query, _mode),
    do: dynamic([t], field_or_blank_value(t.source, mode))

  def dimension("visit:referrer", _query, _mode),
    do: dynamic([t], field_or_blank_value(t.referrer, mode))

  def dimension("visit:device", _query, _mode),
    do: dynamic([t], field_or_blank_value(t.device, mode))

  def dimension("visit:os", _query, _mode), do: dynamic([t], field_or_blank_value(t.os, mode))

  def dimension("visit:os_version", _query, _mode),
    do: dynamic([t], field_or_blank_value(t.os_version, mode))

  def dimension("visit:browser", _query, _mode),
    do: dynamic([t], field_or_blank_value(t.browser, mode))

  def dimension("visit:browser_version", _query, _mode),
    do: dynamic([t], field_or_blank_value(t.browser_version, mode))

  # :TODO: Locations also set extra filters
  def dimension("visit:country", _query, _mode), do: dynamic([t], t.country)
  def dimension("visit:region", _query, _mode), do: dynamic([t], t.region)
  def dimension("visit:city", _query, _mode), do: dynamic([t], t.city)
end
