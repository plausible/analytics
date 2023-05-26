defmodule Plausible.MoneyWithoutCurrency do
  @moduledoc """
  An Ecto type for saving monetary values as integers.

  This type accepts a %Decimal{} struct and converts it to `UInt64`. When
  loading from the database, it casts the value to %Decimal{}. Currency
  information is presumed to be stored in a separate field.

  To avoid extra database storage, missing values are saved as the maximum
  `UInt64` value and loaded as `nil` in runtime.
  """

  use Ecto.Type

  @exponent 6
  @max_uint64 18_446_744_073_709_551_615

  def type, do: :u64

  @doc """
  Casts a %Decimal{} value. If nil or negative, handles it as a missing value.
  """
  def cast(value)

  def cast(%Decimal{} = decimal) do
    if Decimal.positive?(decimal) do
      {:ok, decimal}
    else
      {:ok, nil}
    end
  end

  def cast(nil) do
    {:ok, nil}
  end

  def cast(_any) do
    :error
  end

  @positive_sign 1

  @doc """
  Loads the value from the database as a %Decimal{} or `nil` if missing.
  """
  def load(value)

  def load(missing_value) when missing_value == @max_uint64 do
    {:ok, nil}
  end

  def load(integer) when is_integer(integer) do
    decimal =
      @positive_sign
      |> Decimal.new(integer, -@exponent)
      |> Decimal.normalize()

    {:ok, decimal}
  end

  def load(_any) do
    :error
  end

  @doc """
  Dumps a %Decimal{} to the database as integer with a fixed precision of
  #{@exponent} digits.
  """
  def dump(value)

  def dump(%Decimal{} = decimal) do
    rounded =
      decimal
      |> Decimal.round(@exponent, :half_even)
      |> Decimal.normalize()

    exponent_adjustment = Kernel.abs(-@exponent - rounded.exp)
    integer = Cldr.Math.power_of_10(exponent_adjustment) * rounded.coef * rounded.sign

    {:ok, integer}
  end

  def dump(nil) do
    {:ok, @max_uint64}
  end

  def dump(_any) do
    :error
  end
end
