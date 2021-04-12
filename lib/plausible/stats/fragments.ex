defmodule Plausible.Stats.Fragments do
  defmacro uniq(user_id) do
    quote do
      fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", unquote(user_id))
    end
  end

  defmacro total() do
    quote do
      fragment("toUInt64(round(count(*) * any(_sample_factor)))")
    end
  end

  defmacro sample_percent() do
    quote do
      fragment("if(any(_sample_factor) > 1, round(100 / any(_sample_factor)), 100)")
    end
  end

  defmacro bounce_rate() do
    quote do
      fragment("toUInt32(ifNotFinite(round(sum(is_bounce * sign) / sum(sign) * 100), 0))")
    end
  end

  defmacro visit_duration() do
    quote do
      fragment("toUInt32(ifNotFinite(round(avg(duration * sign)), 0))")
    end
  end

  defmacro coalesce_string(fieldA, fieldB) do
    quote do
      fragment("if(empty(?), ?, ?)", unquote(fieldA), unquote(fieldB), unquote(fieldA))
    end
  end

  defmacro __using__(_) do
    quote do
      import Plausible.Stats.Fragments
    end
  end
end
