defmodule Plausible do
  @moduledoc """
  Build-related macros
  """

  @small_builds [:small, :small_test, :small_dev]

  defmacro __using__(_) do
    quote do
      require Plausible
      import Plausible
    end
  end

  defmacro on_full_build(clauses) do
    do_on_full_build(clauses)
  end

  def do_on_full_build(do: block) do
    do_on_full_build(do: block, else: nil)
  end

  def do_on_full_build(do: do_block, else: else_block) do
    if Mix.env() not in @small_builds do
      quote do
        unquote(do_block)
      end
    else
      quote do
        unquote(else_block)
      end
    end
  end

  defmacro full_build?() do
    full_build? = Mix.env() not in @small_builds

    # Tricking dialyzer as per:
    # https://github.com/elixir-lang/elixir/blob/v1.12.3/lib/elixir/lib/gen_server.ex#L771-L778
    quote do
      :erlang.phash2(1, 1) == 0 and unquote(full_build?)
    end
  end

  defmacro small_build?() do
    small_build? = Mix.env() in @small_builds

    quote do
      unquote(small_build?)
    end
  end
end
