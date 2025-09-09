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

  @spec beginning_of_week(DateTime.t()) :: DateTime.t()
  def beginning_of_week(dt) do
    Timex.beginning_of_week(dt)
  end

  @spec beginning_of_month(DateTime.t()) :: DateTime.t()
  def beginning_of_month(dt) do
    Timex.beginning_of_month(dt)
  end

  @spec beginning_of_year(Date.t()) :: Date.t()
  def beginning_of_year(d) do
    Timex.beginning_of_year(d)
  end

  @spec end_of_week(DateTime.t()) :: DateTime.t()
  def end_of_week(dt) do
    Timex.end_of_week(dt)
  end

  @spec end_of_month(DateTime.t()) :: DateTime.t()
  def end_of_month(dt) do
    Timex.end_of_month(dt)
  end

  @spec end_of_year(Date.t()) :: Date.t()
  def end_of_year(t) do
    Timex.end_of_year(t)
  end

  @spec humanize(DateTime.t()) :: String.t()
  def humanize(%DateTime{} = dt) do
    Timex.Format.DateTime.Formatters.Relative.format!(dt, "{relative}")
  end

  @spec humanize_seconds(pos_integer()) :: String.t()
  def humanize_seconds(seconds) do
    seconds
    |> Timex.Duration.from_seconds()
    |> Timex.format_duration(Timex.Format.Duration.Formatters.Humanized)
  end
end
