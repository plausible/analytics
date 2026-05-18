defmodule Plausible.Stats.Exploration.Journey.Step do
  @moduledoc false

  @type t() :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [:name, :pathname, :label, :includes_subpaths, :subpaths_count, :is_goal]}
  defstruct name: nil,
            pathname: "",
            label: nil,
            includes_subpaths: false,
            subpaths_count: 0,
            is_goal: false

  @journey_end_event "__journey_end__"
  @journey_end_label "No further action"

  @spec journey_end_event() :: String.t()
  def journey_end_event, do: @journey_end_event

  @spec journey_end_label() :: String.t()
  def journey_end_label, do: @journey_end_label

  @spec from(map()) :: t()
  def from(step) do
    new(step.name, step.pathname, step.includes_subpaths, step.subpaths_count, step.is_goal)
  end

  @spec new(String.t(), String.t(), boolean(), non_neg_integer(), boolean()) :: t()
  def new(name, pathname, includes_subpaths \\ false, subpaths_count \\ 0, is_goal \\ false)
      when is_boolean(includes_subpaths) and is_integer(subpaths_count) do
    label =
      cond do
        name == @journey_end_event ->
          @journey_end_label

        name != "pageview" ->
          name

        true ->
          pathname
      end

    %__MODULE__{
      label: label,
      name: name,
      pathname: pathname,
      includes_subpaths: includes_subpaths,
      subpaths_count: subpaths_count,
      is_goal: is_goal
    }
  end
end
