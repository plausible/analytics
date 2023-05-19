defmodule Plausible.ExchangeRateMock do
  @moduledoc false
  @behaviour Money.ExchangeRates

  def init(config) do
    config
  end

  def decode_rates(rates) do
    Money.ExchangeRates.OpenExchangeRates.decode_rates(rates)
  end

  def get_latest_rates(_config) do
    {:ok, %{BRL: Decimal.new("0.7"), EUR: Decimal.new("1.2"), USD: Decimal.new(1)}}
  end

  def get_historic_rates(_date, _config) do
    {:ok, %{BRL: Decimal.new("0.8"), EUR: Decimal.new("1.3"), USD: Decimal.new(2)}}
  end
end
