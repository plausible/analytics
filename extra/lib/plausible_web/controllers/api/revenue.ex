defmodule PlausibleWeb.Controllers.API.Revenue do
  @revenue_metrics [:average_revenue, :total_revenue]
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
          long: Money.to_string!(value)
        }

      _any ->
        value
    end
  end
end
