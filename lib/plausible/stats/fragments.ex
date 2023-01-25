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
  Returns the weekstart for `date`. If the weekstart is before the `not_before`
  boundary, `not_before` is returned.

  ## Examples

  In this pseudo-code example, the fragment returns the weekstart. The
  `not_before` boundary is set to the past Saturday, which is before the
  weekstart, therefore the cap does not apply.

    iex> this_wednesday = ~D[2022-11-09]
    ...> past_saturday = ~D[2022-11-05]
    ...> weekstart_not_before(this_wednesday, past_saturday)
    ~D[2022-11-07]


  In this other example, the fragment returns Tuesday and not the weekstart.
  The `not_before` boundary is set to Tuesday, which is past the weekstart,
  therefore the cap applies.

    iex> this_wednesday = ~D[2022-11-09]
    ...> this_tuesday = ~D[2022-11-08]
    ...> weekstart_not_before(this_wednesday, this_tuesday)
    ~D[2022-11-08]

  """
  defmacro weekstart_not_before(date, not_before) do
    quote do
      fragment(
        "if(toMonday(?) < toDate(?), toDate(?), toMonday(?))",
        unquote(date),
        unquote(not_before),
        unquote(not_before),
        unquote(date)
      )
    end
  end

  @doc """
  Same as Plausible.Stats.Fragments.weekstart_not_before/2 but converts dates to
  the specified timezone.
  """
  defmacro weekstart_not_before(date, not_before, timezone) do
    quote do
      weekstart_not_before(
        to_timezone(unquote(date), unquote(timezone)),
        unquote(not_before)
      )
    end
  end

  defmacro __using__(_) do
    quote do
      import Plausible.Stats.Fragments
    end
  end
end
