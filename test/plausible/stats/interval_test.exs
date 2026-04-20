defmodule Plausible.Stats.IntervalTest do
  use Plausible.DataCase, async: true

  import Plausible.Stats.Interval
  alias Plausible.Stats.{DateTimeRange, Query}

  defp build_query(params) do
    params =
      %{metrics: [:visitors]}
      |> Map.merge(params)
      |> Map.to_list()

    struct!(Query, params)
  end

  describe "default_for_query/1" do
    test "by input_date_range" do
      assert default_for_query(build_query(%{input_date_range: :realtime})) == "minute"
      assert default_for_query(build_query(%{input_date_range: :day})) == "hour"
      assert default_for_query(build_query(%{input_date_range: :"24h"})) == "hour"
      assert default_for_query(build_query(%{input_date_range: {:last_n_days, 7}})) == "day"
      assert default_for_query(build_query(%{input_date_range: {:last_n_months, 12}})) == "month"
    end

    test "by utc_time_range when period input_date_range is :all" do
      year = DateTimeRange.new!(~D[2022-01-01], ~D[2023-01-01], "UTC")
      fifteen_days = DateTimeRange.new!(~D[2022-01-01], ~D[2022-01-15], "UTC")
      day = DateTimeRange.new!(~D[2022-01-01], ~D[2022-01-01], "UTC")

      assert default_for_query(build_query(%{input_date_range: :all, utc_time_range: year})) ==
               "month"

      assert default_for_query(
               build_query(%{input_date_range: :all, utc_time_range: fifteen_days})
             ) ==
               "day"

      assert default_for_query(build_query(%{input_date_range: :all, utc_time_range: day})) ==
               "hour"
    end
  end
end
