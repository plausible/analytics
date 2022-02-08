defmodule Plausible.Stats.Compare do
  def calculate_change(:bounce_rate, old_stats, new_stats) do
    old_count = old_stats[:bounce_rate][:value]
    new_count = new_stats[:bounce_rate][:value]

    if old_count > 0, do: new_count - old_count
  end

  def calculate_change(metric, old_stats, new_stats) do
    old_count = old_stats[metric][:value]
    new_count = new_stats[metric][:value]

    percent_change(old_count, new_count)
  end

  defp percent_change(old_count, new_count) do
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
