defmodule Plausible do
  @moduledoc """
  Plausible keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  defmacro __using__(_) do
    quote do
      require Plausible
      import Plausible, only: [ce?: 1, ee?: 1, ee?: 0]
    end
  end

  defmacro ce?(do: block) do
    quote do
      if Mix.env() == :community do
        unquote(block)
      end
    end
  end

  defmacro ee?(do: block) do
    quote do
      if Mix.env() != :community do
        unquote(block)
      end
    end
  end

  defmacro ee?() do
    Mix.env() != :community
  end
end
