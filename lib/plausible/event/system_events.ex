defmodule Plausible.Event.SystemEvents do
  @moduledoc """
  System events are events that require at least one form of special treatment by the application.
  They are distinguished by event name.

  For some system events, the tracking API may reject events that don't match the expected format
  (e.g. engagement events without scroll depth or engagement time defined).

  For other system events, it may accept the event (e.g. "Outbound Link: Click" with the url prop not set).

  System events may have corresponding system-managed goals, in which case the goal name and event name will be the same
  (e.g. "Outbound Link: Click" goal is managed by the application). The system will only be able to manage these goals properly
  if they are not renamed by the user.
  """
  @pageview_event_name "pageview"
  @engagement_event_name "engagement"

  @outbound_link_click_event_name "Outbound Link: Click"
  @cloaked_link_click_event_name "Cloaked Link: Click"
  @file_download_link_click_event_name "File Download"

  @error_404_event_name "404"
  @wordpress_form_completions_event_name "WP Form Completions"
  @form_submission_event_name "Form: Submission"

  @all_system_events [
    @pageview_event_name,
    @engagement_event_name,
    @outbound_link_click_event_name,
    @cloaked_link_click_event_name,
    @file_download_link_click_event_name,
    @error_404_event_name,
    @wordpress_form_completions_event_name,
    @form_submission_event_name
  ]

  @interactive_events @all_system_events

  @events_with_url_prop [
    @outbound_link_click_event_name,
    @cloaked_link_click_event_name,
    @file_download_link_click_event_name
  ]

  @events_with_path_prop [
    @error_404_event_name,
    @wordpress_form_completions_event_name,
    @form_submission_event_name
  ]

  @events_with_engagement_props [
    @engagement_event_name
  ]

  def events() do
    @all_system_events
  end

  def events_with_interactive_always_true() do
    @interactive_events
  end

  def events_with_url_prop() do
    @events_with_url_prop
  end

  def events_with_path_prop() do
    @events_with_path_prop
  end

  def events_with_engagement_props() do
    @events_with_engagement_props
  end

  @spec special_events_for_prop_key(String.t()) :: [String.t()]
  def special_events_for_prop_key("url"), do: events_with_url_prop()
  def special_events_for_prop_key("path"), do: events_with_path_prop()

  @doc """
  Checks if the event name is for a system event / system goal that should have the event.props.path synced with the event.pathname property.

  ### Examples
  iex> sync_props_path_with_pathname?("404", [{"path", "/foo"}])
  false

  Note: Should not override event.props.path if it is set deliberately to nil
  iex> sync_props_path_with_pathname?("404", [{"path", nil}])
  false

  iex> sync_props_path_with_pathname?("404", [{"other", "value"}])
  true

  iex> sync_props_path_with_pathname?("404", [])
  true
  """
  @spec sync_props_path_with_pathname?(String.t(), [{String.t(), String.t()}]) :: boolean()
  def sync_props_path_with_pathname?(event_name, props_in_request) do
    event_name in events_with_path_prop() and
      not Enum.any?(props_in_request, fn {k, _} -> k == "path" end)
  end
end
