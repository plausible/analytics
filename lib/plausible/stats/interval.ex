defmodule Plausible.Stats.Interval do
  @moduledoc """
  [DEPRECATED] Stats API v2 handles "intervals" as time dimensions.
  See `Plausible.Stats.ApiQueryParser.parse_dimensions/1`.
  """

  alias Plausible.Stats.{DateTimeRange, Query}

  @intervals ["minute", "hour", "day", "week", "month"]

  def valid?(interval) do
    interval in @intervals
  end

  @doc """
  Returns the suggested interval for a given Stats API v1 (legacy) query.
  """
  def default_for_query(query)

  def default_for_query(%Query{
        input_date_range: :all,
        utc_time_range: %DateTimeRange{first: first, last: last}
      }) do
    cond do
      Plausible.Times.diff(last, first, :month) > 0 ->
        "month"

      DateTime.diff(last, first, :day) > 0 ->
        "day"

      true ->
        "hour"
    end
  end

  def default_for_query(%Query{} = query) do
    case query.input_date_range do
      period when period in [:realtime, :realtime_30m] -> "minute"
      :day -> "hour"
      :"24h" -> "hour"
      {:last_n_days, _} -> "day"
      period when period in [:custom, :month] -> "day"
      {:last_n_months, _} -> "month"
      :year -> "month"
    end
  end
end
