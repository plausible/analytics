defmodule PlausibleWeb.StatsView do
  use PlausibleWeb, :view

  def bar(count, all, color \\ :blue) do
    ~E"""
    <div class="bar">
      <div class="bar__fill bg-<%= color %>" style="width: <%= bar_width(count, all) %>%;"></div>
    </div>
    """
  end

  defp bar_width(count, all) do
    count / (List.first(all) |> elem(1)) * 100
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

  def icon_for("Desktop") do
    ~E"""
    <svg width="16px" height="16px" style="transform: translateY(3px)" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-monitor"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
    """
  end

  def explanation_for("Mobile") do
    "up to 600px"
  end

  def explanation_for("Tablet") do
    "600px to 992px"
  end

  def explanation_for("Desktop") do
    "from 992px"
  end

  defp custom_range_text("custom", dates) do
    {:ok, first} = Timex.format(dates.first, "{Mshort} {D}")
    {:ok, last} = Timex.format(dates.last, "{Mshort} {D}")
    "#{first} - #{last}"
  end

  defp custom_range_text(_, _) do
    "Custom range"
  end
end
