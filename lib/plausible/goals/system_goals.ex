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

  @spec maybe_sync_props_path_with_pathname(String.t(), map()) ::
          {:ok, map()} | {:error, String.t()}
  def maybe_sync_props_path_with_pathname(_pathname, %{"path" => _} = _props) do
    {:error, "Path has been already set in props, won't override"}
  end

  def maybe_sync_props_path_with_pathname(pathname, %{} = props) do
    {:ok, Map.merge(props, %{"path" => pathname})}
  end
end
