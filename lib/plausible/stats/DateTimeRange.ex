defmodule Plausible.Stats.DateTimeRange do
  @moduledoc false

  defstruct [:first, :last, :datetime?]

  def new(first, last) do
    %__MODULE__{first: first, last: last}
  end
end
