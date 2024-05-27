defmodule Plausible.Funnel.Const do
  @moduledoc """
  Compile-time convenience constants for funnel characteristics.
  """
  @min_steps 2
  @max_steps 8

  defmacro min_steps() do
    quote do
      unquote(@min_steps)
    end
  end

  defmacro max_steps() do
    quote do
      unquote(@max_steps)
    end
  end

  defmacro __using__(_opts \\ []) do
    quote do
      require Plausible.Funnel.Const
      alias Plausible.Funnel
    end
  end
end
