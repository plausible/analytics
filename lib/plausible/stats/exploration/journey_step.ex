defmodule Plausible.Stats.Exploration.JourneyStep do
  @moduledoc false

  @type t() :: %__MODULE__{}

  @derive {Jason.Encoder, only: [:name, :pathname, :label]}
  defstruct [:name, :pathname, :label]

  @spec from(map()) :: t()
  def from(step) do
    new(step.name, step.pathname)
  end

  @spec new(String.t(), String.t()) :: t()
  def new(name, pathname) do
    %__MODULE__{
      label: if(name == "pageview", do: "Visit", else: name) <> " " <> pathname,
      name: name,
      pathname: pathname
    }
  end
end
