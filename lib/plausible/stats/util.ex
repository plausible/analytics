defmodule Plausible.Stats.Util do
  @moduledoc """
  Utilities for modifying stat results
  """

  @doc """
  This function adds the `visitors` metric into the list of
  given metrics if it's not already there and if it is needed
  for any of the other metrics to be calculated.
  """
  def maybe_add_visitors_metric(metrics) do
    needed? =
      Enum.any?(
        [:percentage, :conversion_rate, :group_conversion_rate, :time_on_page],
        &(&1 in metrics)
      )

    if needed? and :visitors not in metrics do
      metrics ++ [:visitors]
    else
      metrics
    end
  end

  def shortname(_query, metric) when is_atom(metric), do: metric
  def shortname(_query, "time:" <> _), do: :time

  def shortname(query, dimension) do
    index = Enum.find_index(query.dimensions, &(&1 == dimension))
    :"dim#{index}"
  end

  def percentage(x, y) when is_integer(x) and x > 0 and is_integer(y) and y > 0 do
    result =
      x
      |> Decimal.div(y)
      |> Decimal.mult(100)
      |> Decimal.round(2)
      |> Decimal.to_string()

    case result do
      <<compact::binary-size(1), ".00">> -> compact
      <<compact::binary-size(2), ".00">> -> compact
      <<compact::binary-size(3), ".00">> -> compact
      decimal -> decimal
    end
  end

  def percentage(_x, _y) do
    "0"
  end
end
