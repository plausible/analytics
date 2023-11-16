defmodule Plausible do
  @moduledoc """
  Build-related macros
  """

  @small_builds [:small, :small_test]

  defmacro __using__(_) do
    quote do
      require Plausible
      import Plausible
    end
  end

  defmacro on_small_build(do: block) do
    if Mix.env() in @small_builds do
      quote do
        unquote(block)
      end
    end
  end

  defmacro on_full_build(do: block) do
    if Mix.env() not in @small_builds do
      quote do
        unquote(block)
      end
    end
  end

  defmacro full_build?() do
    full_build? = Mix.env() not in @small_builds

    quote do
      unquote(full_build?)
    end
  end

  defmacro small_build?() do
    small_build? = Mix.env() in @small_builds

    quote do
      unquote(small_build?)
    end
  end
end
