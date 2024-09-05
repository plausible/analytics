defmodule Plausible.Stats.Legacy.Dimensions do
  @moduledoc """
  Deprecated module. See QueryParser for list of valid dimensions
  """
  @event_props ["event:page", "event:name", "event:goal", "event:hostname"]
  @session_props [
    "visit:source",
    "visit:channel",
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

  def valid?(prop) when prop in @event_props, do: true
  def valid?(prop) when prop in @session_props, do: true
  def valid?("event:props:" <> prop) when byte_size(prop) > 0, do: true
  def valid?(_), do: false
end
