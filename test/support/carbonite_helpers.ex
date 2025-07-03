defmodule Plausible.CarboniteHelpers do
  defmacro __using__(_) do
    quote do
      require Plausible.CarboniteHelpers
      import Plausible.CarboniteHelpers
    end
  end

  defmacro skip_audit(opts \\ [], do: block) do
    quote do
      wrap? = Keyword.get(unquote(opts), :wrap?, false)

      fun = fn ->
        IO.puts(:ignore)
        Carbonite.override_mode(Plausible.Repo, to: :ignore)
        result = unquote(block)
        Carbonite.override_mode(Plausible.Repo, to: :capture)
        IO.puts(:capture)
        result
      end

      if wrap? do
        r =
          Plausible.Repo.transaction(fn ->
            case fun.() do
              {:ok, ret} -> ret
              {:error, e} -> Plausible.Repo.rollback(e)
              other -> other
            end
          end)

        case r do
          {:ok, {:ok, ret}} -> {:ok, ret}
          {:ok, ret} -> ret
          other -> other
        end
      else
        fun.()
      end
    end
  end
end
