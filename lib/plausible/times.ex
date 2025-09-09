defmodule Plausible.Times do
  @moduledoc """
  API for working with time wrapping around external libraries where necessary.
  """

  @spec today(String.t()) :: Date.t()
  def today(tz) do
    tz
    |> DateTime.now!()
    |> DateTime.to_date()
  end

  @spec diff(Date.t() | DateTime.t(), Date.t() | DateTime.t(), :month | :week) :: integer()
  def diff(a, b, unit) do
    unit =
      case unit do
        :week -> :weeks
        :month -> :months
      end

    Timex.diff(a, b, unit)
  end

  @spec parse!(String.t(), String.t(), :default | :strftime) :: DateTime.t() | NaiveDateTime.t()
  def parse!(str, format, tokenizer \\ :default)

  def parse!(str, "{RFC1123}" = format, :default) do
    Timex.parse!(str, format)
  end

  def parse!(str, format, :strftime) do
    Timex.parse!(str, format, :strftime)
  end
end
