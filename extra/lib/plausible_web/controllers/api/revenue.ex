defmodule PlausibleWeb.Controllers.API.Revenue do
  @moduledoc """
  Revenue specific functions for the API scope
  """

  @revenue_metrics Plausible.Stats.Goal.Revenue.revenue_metrics()
  def format_revenue_metric({metric, value}) do
    if metric in @revenue_metrics do
      {metric, format_money(value)}
    else
      {metric, value}
    end
  end

  def format_money(value) do
    case value do
      %Money{} ->
        %{
          short: Money.to_string!(value, format: :short, fractional_digits: 1),
          long: Money.to_string!(value),
          currency: value.currency
        }

      _any ->
        value
    end
  end
end
