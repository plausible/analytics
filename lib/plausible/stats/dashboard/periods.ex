defmodule Plausible.Stats.Dashboard.Periods do
  @all [
    {"realtime", :realtime, "Realtime"},
    {"day", :day, "Today"},
    {"month", :month, "Month to date"},
    {"year", :year, "Year to date"},
    {"all", :all, "All"},
    {"7d", {:last_n_days, 7}, "Last 7 days"},
    {"28d", {:last_n_days, 28}, "Last 28 days"},
    {"30d", {:last_n_days, 30}, "Last 30 days"},
    {"91d", {:last_n_days, 91}, "Last 91 days"},
    {"6mo", {:last_n_months, 6}, "Last 6 months"},
    {"12mo", {:last_n_months, 12}, "Last 12 months"},
  ]

  def all(), do: @all

  @shorthands Enum.map(@all, &(elem(&1, 0)))

  def shorthands(), do: @shorthands

  @input_date_ranges Map.new(@all, fn {shortcut, input_date_range, _label} ->
    {shortcut, input_date_range}
  end)

  def input_date_ranges(), do: @input_date_ranges

  def input_date_range_for(period), do: @input_date_ranges[period]

  @labels Map.new(@all, fn {shortcut, _input_date_range, label} ->
    {shortcut, label}
  end)

  def labels(), do: @labels

  def label_for(period), do: @labels[period]
end
