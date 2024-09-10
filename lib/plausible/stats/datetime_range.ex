defmodule Plausible.Stats.DateTimeRange do
  @moduledoc """
  Defines a struct similar `Date.Range`, but with `DateTime` instead of `Date`.

  The structs should be created with the `new!/2` function.
  """

  @enforce_keys [:first, :last]
  defstruct [:first, :last]

  @type t() :: %__MODULE__{
          first: %DateTime{},
          last: %DateTime{}
        }

  @doc """
  Creates a `DateTimeRange` struct from the given `%Date{}` structs.

  The first datetime will become the first date at 00:00:00, and the last datetime
  will become the last date at 23:59:59. Both dates will be turned into `%DateTime{}`
  structs in the given timezone.
  """
  def new!(%Date{} = first, %Date{} = last, timezone) do
    first =
      case DateTime.new(first, ~T[00:00:00], timezone) do
        {:ok, datetime} -> datetime
        {:gap, _just_before, just_after} -> just_after
        {:ambiguous, _first_datetime, second_datetime} -> second_datetime
      end

    last =
      case DateTime.new(last, ~T[23:59:59], timezone) do
        {:ok, datetime} -> datetime
        {:gap, just_before, _just_after} -> just_before
        {:ambiguous, first_datetime, _second_datetime} -> first_datetime
      end

    new!(first, last)
  end

  def new!(%DateTime{} = first, %DateTime{} = last) do
    first = DateTime.truncate(first, :second)
    last = DateTime.truncate(last, :second)

    %__MODULE__{first: first, last: last}
  end

  def to_timezone(%__MODULE__{first: first, last: last}, timezone) do
    first = DateTime.shift_zone!(first, timezone)
    last = DateTime.shift_zone!(last, timezone)

    %__MODULE__{first: first, last: last}
  end

  def to_date_range(datetime_range, timezone) do
    %__MODULE__{first: first, last: last} = to_timezone(datetime_range, timezone)

    first = DateTime.to_date(first)
    last = DateTime.to_date(last)

    Date.range(first, last)
  end
end
