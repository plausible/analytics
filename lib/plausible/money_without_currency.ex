defmodule Plausible.MoneyWithoutCurrency do
  @moduledoc """
  An Ecto type for saving monetary values as integers.

  This type accepts a %Decimal{} struct and converts it to `UInt64`. When
  loading from the database, it casts the value to %Decimal{}. Currency
  information is presumed to be stored in a separate field.

  To avoid extra database storage, missing values are saved as the maximum
  `UInt64` value and loaded as `nil` in runtime.
  """

  # This custom type does not have any params, but it is still defined as
  # Ecto.ParameterizedType to work with nils. Ecto.Type does not defer nils to
  # load and dump functions.
  use Ecto.ParameterizedType

  @exponent 6
  @max_uint64 18_446_744_073_709_551_615
  @positive_sign 1

  def init(opts) do
    Enum.into(opts, %{})
  end

  def type(_params) do
    Ecto.ParameterizedType.init(Ch, type: "UInt64")
  end

  @doc """
  Casts a %Decimal{} value. If nil or negative, handles it as a missing value.
  """
  def cast(data, _params) do
    case data do
      %Decimal{} = decimal -> {:ok, decimal}
      nil -> {:ok, nil}
      _any -> :error
    end
  end

  @doc """
  Loads the value from the database as a %Decimal{} or `nil` if missing.
  """
  def load(data, _loader, _params) do
    case data do
      data when data == @max_uint64 ->
        {:ok, nil}

      data when is_integer(data) ->
        decimal =
          @positive_sign
          |> Decimal.new(data, -@exponent)
          |> Decimal.normalize()

        {:ok, decimal}

      _any ->
        :error
    end
  end

  @doc """
  Dumps a %Decimal{} to the database as integer with a fixed precision of
  #{@exponent} digits.
  """
  def dump(data, _dumper, _params) do
    case data do
      %Decimal{} = decimal ->
        rounded =
          decimal
          |> Decimal.round(@exponent, :half_even)
          |> Decimal.normalize()

        exponent_adjustment = Kernel.abs(-@exponent - rounded.exp)
        integer = Cldr.Math.power_of_10(exponent_adjustment) * rounded.coef * rounded.sign

        {:ok, integer}

      nil ->
        {:ok, @max_uint64}

      _any ->
        :error
    end
  end

  def missing_value do
    @max_uint64
  end
end
