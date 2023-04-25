defmodule Plausible.Stats.Props do
  @event_props ["event:page", "event:page_match", "event:name", "event:goal"]
  @session_props [
    "visit:source",
    "visit:country",
    "visit:region",
    "visit:city",
    "visit:entry_page",
    "visit:exit_page",
    "visit:referrer",
    "visit:utm_medium",
    "visit:utm_source",
    "visit:utm_campaign",
    "visit:utm_content",
    "visit:utm_term",
    "visit:device",
    "visit:os",
    "visit:os_version",
    "visit:browser",
    "visit:browser_version"
  ]

  def event_props(), do: @event_props

  def valid_prop?(prop) when prop in @event_props, do: true
  def valid_prop?(prop) when prop in @session_props, do: true
  def valid_prop?("event:props:" <> prop) when byte_size(prop) > 0, do: true
  def valid_prop?(_), do: false
end
