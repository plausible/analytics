defmodule Plausible do
  @moduledoc """
  Build-related macros
  """

  @ce_builds [:ce, :ce_test, :ce_dev]

  defmacro __using__(_) do
    quote do
      require Plausible
      import Plausible
    end
  end

  defmacro on_ee(clauses) do
    do_on_ee(clauses)
  end

  defmacro on_ce(clauses) do
    do_on_ce(clauses)
  end

  defmacro ee?() do
    ee? = Mix.env() not in @ce_builds

    # Tricking dialyzer as per:
    # https://github.com/elixir-lang/elixir/blob/v1.12.3/lib/elixir/lib/gen_server.ex#L771-L778
    quote do
      :erlang.phash2(1, 1) == 0 and unquote(ee?)
    end
  end

  defmacro ce?() do
    ce_build? = Mix.env() in @ce_builds

    quote do
      unquote(ce_build?)
    end
  end

  defp do_on_ce(do: block) do
    do_on_ee(do: nil, else: block)
  end

  defp do_on_ee(do: block) do
    do_on_ee(do: block, else: nil)
  end

  defp do_on_ee(do: do_block, else: else_block) do
    if Mix.env() not in @ce_builds do
      quote do
        unquote(do_block)
      end
    else
      quote do
        unquote(else_block)
      end
    end
  end

  if Mix.env() in @ce_builds do
    def product_name do
      "Plausible CE"
    end
  else
    def product_name do
      "Plausible Analytics"
    end
  end
end
