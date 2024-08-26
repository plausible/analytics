defmodule Plausible.Stats.NaiveDateTimeRange do
  @moduledoc """
  Defines a struct similar `Date.Range`, but with `NaiveDateTime` instead of `Date`.

  The structs should be created with the `new!/2` function.
  """

  @enforce_keys [:first, :last]
  defstruct [:first, :last]

  @type t() :: %__MODULE__{
          first: %NaiveDateTime{},
          last: %NaiveDateTime{}
        }

  @doc """
  Creates a `NaiveDateTimeRange` struct, where the `first` and `last` datetimes are
  truncated to a `:second` precision.

  Arguments can also be given as `Date` structs, in which case the first datetime
  will become that same day at 00:00:00, and the last datetime will be the next day
  at 00:00:00.
  """
  def new!(first, last)

  def new!(%Date{} = first, %Date{} = last) do
    first = NaiveDateTime.new!(first, ~T[00:00:00])
    last = Date.shift(last, day: 1) |> NaiveDateTime.new!(~T[00:00:00])

    new!(first, last)
  end

  def new!(%NaiveDateTime{} = first, %NaiveDateTime{} = last) do
    first = NaiveDateTime.truncate(first, :second)
    last = NaiveDateTime.truncate(last, :second)

    %__MODULE__{first: first, last: last}
  end

  def to_date_range(%__MODULE__{first: first, last: last}) do
    first = NaiveDateTime.to_date(first)

    last =
      if NaiveDateTime.to_time(last) == ~T[00:00:00] do
        NaiveDateTime.add(last, -1, :day) |> NaiveDateTime.to_date()
      else
        NaiveDateTime.to_date(last)
      end

    Date.range(first, last)
  end
end
