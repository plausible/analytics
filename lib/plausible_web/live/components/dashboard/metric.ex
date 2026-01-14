defmodule PlausibleWeb.Components.Dashboard.Metric do
  @moduledoc """
  Components for rendering metric data.
  """

  use PlausibleWeb, :component

  @formatters %{
    visitors: :number_short,
    conversion_rate: :percentage,
    group_conversion_rate: :percentage
  }

  attr :name, :atom, required: true
  attr :value, :any

  def value(assigns) do
    ~H"""
    <div class="cursor-default">
      {format_value(@name, @value)}
    </div>
    """
  end

  defp format_value(name, value) do
    apply_format(@formatters[name], value)
  end

  @hundred_billion :math.pow(10, 11)
  @billion :math.pow(10, 9)
  @hundred_million :math.pow(10, 8)
  @million :math.pow(10, 6)
  @hundred_thousand :math.pow(10, 5)
  @thousand :math.pow(10, 3)

  defp apply_format(:number_short, value) when is_number(value) do
    cond do
      value >= @hundred_billion -> divided(value, @billion)
      value >= @billion -> divided(value, @billion, 2)
      value >= @hundred_million -> divided(value, @million)
      value >= @million -> divided(value, @million, 2)
      value >= @hundred_thousand -> divided(value, @thousand)
      value >= @thousand -> divided(value, @thousand, 2)
      true -> value
    end
  end

  defp apply_format(:number_short, _), do: "-"

  defp apply_format(:percentage, value) do
    if value do
      :erlang.float_to_binary(value, decimals: 2) <> "%"
    else
      "-"
    end
  end

  defp divided(value, divisor, precision \\ 0) do
    :erlang.float_to_binary(value / divisor, decimals: precision)
  end
end
