defmodule PlausibleWeb.StatsView do
  use PlausibleWeb, :view

  def large_number_format(n) do
    cond do
      n >= 1_000 && n < 1_000_000 ->
        thousands = trunc(n / 100) / 10
        if thousands == trunc(thousands) || n >= 100_000 do
          "#{trunc(thousands)}k"
        else
          "#{thousands}k"
        end
      n >= 1_000_000 && n < 100_000_000 ->
        millions = trunc(n / 100_000) / 10
        if millions == trunc(millions) do
          "#{trunc(millions)}m"
        else
          "#{millions}m"
        end
     true ->
       Integer.to_string(n)
    end
  end

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
        "on #{Timex.format!(query.date_range.first, "{Mfull} {D}")}"
      "month" ->
        "in #{Timex.format!(query.date_range.first, "{Mfull} {YYYY}")}"
      "7d" ->
        "in the last 7 days"
      "3mo" ->
        "in the last 3 months"
      "6mo" ->
        "in the last 6 months"
    end
  end

  def query_params(query) do
    case query.period do
      "day" ->
        date = Date.to_iso8601(query.date_range.first)
        "?period=day&date=#{date}"
      "month" ->
        date = Date.to_iso8601(query.date_range.first)
        "?period=month&date=#{date}"
      "7d" ->
        "?period=7d"
      "3mo" ->
        "?period=3mo"
      "6mo" ->
        "?period=6mo"
    end
  end

  def today(site) do
    Timex.now(site.timezone)
    |> DateTime.to_date
  end

  def this_month(site) do
    Timex.now(site.timezone)
    |> DateTime.to_date
    |> Timex.beginning_of_month
  end

  def last_month(site) do
    this_month(site)
    |> Timex.shift(months: -1)
  end

  def timeframe_text(site, query) do
    case query.period do
      "6mo" ->
        "Last 6 months"
      "3mo" ->
        "Last 3 months"
      "month" ->
        if query.date_range.first == this_month(site) do
          "This month"
        else
          Timex.format!(query.date_range.first, "{Mfull} {YYYY}")
        end
      "7d" ->
        "Last 7 days"
      "day" ->
        if query.date_range.first == today(site) do
          "Today"
        else
          Timex.format!(query.date_range.first, "{D} {Mfull} {YYYY}")
        end
      _ ->
        "wat"
    end
  end

  defp bar_width(count, all) do
    max = Enum.max_by(all, fn {_, count} -> count end) |> elem(1)
    count / max * 100
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
end
