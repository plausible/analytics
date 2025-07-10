defmodule Plausible.Goals.SystemGoals do
  @moduledoc """
  This module contains logic for special goals
  """

  # Special system goals which can be filtered by 'url' custom property
  @goals_with_url ["Outbound Link: Click", "Cloaked Link: Click", "File Download"]

  # Special system goals which can be filtered by 'path' custom property
  @goals_with_path ["404", "WP Form Completions", "Form: Submission"]

  @spec goals_with_url() :: [String.t()]
  def goals_with_url() do
    @goals_with_url
  end

  @spec goals_with_path() :: [String.t()]
  def goals_with_path() do
    @goals_with_path
  end

  @spec special_goals_for(String.t()) :: [String.t()]
  def special_goals_for("event:props:url"), do: goals_with_url()
  def special_goals_for("event:props:path"), do: goals_with_path()

  @doc """
  Checks if the event name is for a special goal that should have the event.props.path synced with the event.pathname property.

  ### Examples
  iex> should_sync_props_path_with_pathname?("404", [{"path", "/foo"}])
  false

  iex> should_sync_props_path_with_pathname?("404", [{"path", nil}])
  false

  iex> should_sync_props_path_with_pathname?("404", [])
  true
  """
  @spec should_sync_props_path_with_pathname?(String.t(), [{String.t(), String.t()}]) :: boolean()
  def should_sync_props_path_with_pathname?(event_name, props_in_request) do
    event_name in goals_with_path() and
      not Enum.any?(props_in_request, fn {k, _} -> k == "path" end)
  end
end
