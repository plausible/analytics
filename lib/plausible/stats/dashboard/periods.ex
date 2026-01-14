defmodule Plausible.Stats.Dashboard.Periods do
  @moduledoc false

  @all [
    {"realtime", :realtime},
    {"day", :day},
    {"month", :month},
    {"year", :year},
    {"all", :all},
    {"7d", {:last_n_days, 7}},
    {"28d", {:last_n_days, 28}},
    {"30d", {:last_n_days, 30}},
    {"91d", {:last_n_days, 91}},
    {"6mo", {:last_n_months, 6}},
    {"12mo", {:last_n_months, 12}}
  ]

  def all(), do: @all

  @shorthands Enum.map(@all, &elem(&1, 0))

  def shorthands(), do: @shorthands

  @input_date_ranges Map.new(@all)

  def input_date_ranges(), do: @input_date_ranges

  def input_date_range_for(period), do: @input_date_ranges[period]

  def label_for(:day, %Date{} = date) do
    Calendar.strftime(date, "%a, %-d %b")
  end

  def label_for(:month, %Date{} = date) do
    Calendar.strftime(date, "%B %Y")
  end

  def label_for(:year, %Date{} = date) do
    Calendar.strftime(date, "Year of %Y")
  end

  def label_for(:realtime, _date), do: "Realtime"
  def label_for(:day, _date), do: "Today"
  def label_for(:month, _date), do: "Month to date"
  def label_for(:year, _date), do: "Year to date"
  def label_for(:all, _date), do: "All"
  def label_for({:last_n_days, 7}, _date), do: "Last 7 days"
  def label_for({:last_n_days, 28}, _date), do: "Last 28 days"
  def label_for({:last_n_days, 30}, _date), do: "Last 30 days"
  def label_for({:last_n_days, 91}, _date), do: "Last 91 days"
  def label_for({:last_n_months, 6}, _date), do: "Last 6 months"
  def label_for({:last_n_months, 12}, _date), do: "Last 12 months"
end
