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

  @spec from(map()) :: t()
  def from(step) do
    new(step.name, step.pathname, step.includes_subpaths, step.subpaths_count, step.is_goal)
  end

  @spec new(String.t(), String.t(), boolean(), non_neg_integer(), boolean()) :: t()
  def new(name, pathname, includes_subpaths \\ false, subpaths_count \\ 0, is_goal \\ false)
      when is_boolean(includes_subpaths) and is_integer(subpaths_count) do
    label =
      if name != "pageview" do
        name
      else
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
