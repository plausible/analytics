defmodule Plausible.Stats.Compare do
  def calculate_change(:conversion_rate, old_value, new_value) do
    Float.round(new_value - old_value, 1)
  end

  def calculate_change(:bounce_rate, old_count, new_count) do
    if old_count > 0, do: new_count - old_count
  end

  def calculate_change(_metric, old_count, new_count) do
    percent_change(old_count, new_count)
  end

  def percent_change(nil, _new_count), do: nil
  def percent_change(_old_count, nil), do: nil

  def percent_change(%{value: old_count}, %{value: new_count}) do
    percent_change(old_count, new_count)
  end

  def percent_change(old_count, new_count) do
    cond do
      old_count == 0 and new_count > 0 ->
        100

      old_count == 0 and new_count == 0 ->
        0

      true ->
        round((new_count - old_count) / old_count * 100)
    end
  end
end
