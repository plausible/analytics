defmodule PlausibleWeb.StatsView do
  use PlausibleWeb, :view

  def bar(count, all, color \\ :blue) do
    ~E"""
    <div class="bar">
      <div class="bar__fill bg-<%= color %>" style="width: <%= bar_width(count, all) %>%;"></div>
    </div>
    """
  end

  def timeframe_to_human(query) do
    case query.period do
      "day" ->
        "today"
      "week" ->
        "in the last week"
      "month" ->
        "in the last month"
      "custom" ->
    end
  end

  defp bar_width(count, all) do
    max = Enum.max_by(all, fn {_, count} -> count end) |> elem(1)
    count / max * 100
  end

  def clean_number(number, decimals \\ 2) do
    if round(number) == number do
      round(number)
    else
      :erlang.float_to_binary(number, decimals: decimals)
    end
  end

  def to_percentage(n, decimal \\ 2) do
    percent = clean_number(n * 100, decimal)
    "#{percent}%"
  end

  def icon_for("Mobile") do
    ~E"""
    <svg width="16px" height="16px" style="transform: translateY(3px)" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-smartphone"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12" y2="18"/></svg>
    """
  end

  def icon_for("Tablet") do
    ~E"""
    <svg width="16px" height="16px" style="transform: translateY(3px)" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-tablet"><rect x="4" y="2" width="16" height="20" rx="2" ry="2" transform="rotate(180 12 12)"/><line x1="12" y1="18" x2="12" y2="18"/></svg>
    """
  end

  def icon_for("Laptop") do
    ~E"""
    <svg width="16px" height="16px" style="transform: translateY(3px)" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-laptop"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="2" y1="20" x2="22" y2="20"/></svg>
    """
  end

  def icon_for("Desktop") do
    ~E"""
    <svg width="16px" height="16px" style="transform: translateY(3px)" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-monitor"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
    """
  end

  def explanation_for("Mobile") do
    "up to 576px"
  end

  def explanation_for("Tablet") do
    "576px to 992px"
  end

  def explanation_for("Laptop") do
    "992px to 1440px"
  end

  def explanation_for("Desktop") do
    "above 1440px"
  end

  defp custom_range_text(dates) do
    {:ok, first} = Timex.format(dates.first, "{Mshort} {D}")
    {:ok, last} = Timex.format(dates.last, "{Mshort} {D}")
    "#{first} to #{last}"
  end
end
