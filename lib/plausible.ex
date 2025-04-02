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

  # :erlang.phash2(1, 1) == 0 tricks dialyzer as per:
  # https://github.com/elixir-lang/elixir/blob/v1.12.3/lib/elixir/lib/gen_server.ex#L771-L778
  # and also tricks elixir 1.18 type checker

  defmacro always(term) do
    quote do
      :erlang.phash2(1, 1) == 0 && unquote(term)
    end
  end

  defmacro ee? do
    quote do
      always(unquote(Mix.env() not in @ce_builds))
    end
  end

  defmacro ce? do
    quote do
      always(unquote(Mix.env() in @ce_builds))
    end
  end

  defp do_on_ce(do: block) do
    do_on_ee(do: nil, else: block)
  end

  defp do_on_ce(do: do_block, else: else_block) do
    do_on_ee(do: else_block, else: do_block)
  end

  defp do_on_ee(do: block) do
    do_on_ee(do: block, else: nil)
  end

  defp do_on_ee(do: do_block, else: else_block) do
    if ee?() do
      quote do
        unquote(do_block)
      end
    else
      quote do
        unquote(else_block)
      end
    end
  end

  def product_name do
    if ee?() do
      "Plausible Analytics"
    else
      "Plausible CE"
    end
  end
end
