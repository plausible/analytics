defmodule Plausible do
  @moduledoc """
  Build-related macros
  """

  defmacro __using__(_) do
    quote do
      require Plausible
      import Plausible, only: [ce?: 1, ee?: 1, ee?: 0, ce?: 0]
    end
  end

  defmacro ce?(do: block) do
    if Mix.env() in [:community, :community_test] do
      quote do
        unquote(block)
      end
    end
  end

  defmacro ee?(do: block) do
    if Mix.env() not in [:community, :community_test] do
      quote do
        unquote(block)
      end
    end
  end

  defmacro ee?() do
    ee? = Mix.env() not in [:community, :community_test]

    quote do
      unquote(ee?)
    end
  end

  defmacro ce?() do
    ee? = Mix.env() in [:community, :community_test]

    quote do
      unquote(ee?)
    end
  end
end
