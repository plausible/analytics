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

  @doc """
  Converts time or date and time to the specified timezone.

  Reference: https://clickhouse.com/docs/en/sql-reference/functions/date-time-functions/#totimezone
  """
  defmacro to_timezone(date, timezone) do
    quote do
      fragment("toTimeZone(?, ?)", unquote(date), unquote(timezone))
    end
  end

  @doc """
  Returns the nearest Monday not past a given date. If the nearest Monday is
  past the given date, returns the latter.
  """
  defmacro nearest_monday_not_past(date_to_round, not_past_date) do
    quote do
      fragment(
        "if(toMonday(?) < toDate(?), toDate(?), toMonday(?))",
        unquote(date_to_round),
        unquote(not_past_date),
        unquote(not_past_date),
        unquote(date_to_round)
      )
    end
  end

  @doc """
  Same as Plausible.Stats.Fragments.nearest_monday_not_past/2 but converts dates
  to the specified timezone.
  """
  defmacro nearest_monday_not_past(date_to_round, not_past_date, timezone) do
    quote do
      nearest_monday_not_past(
        to_timezone(unquote(date_to_round), unquote(timezone)),
        unquote(not_past_date)
      )
    end
  end

  defmacro __using__(_) do
    quote do
      import Plausible.Stats.Fragments
    end
  end
end
