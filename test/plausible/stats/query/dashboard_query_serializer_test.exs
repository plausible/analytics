defmodule Plausible.Stats.DashboardQuerySerializerTest do
  use Plausible.DataCase
  import Plausible.Stats.{DashboardQuerySerializer}
  alias Plausible.Stats.ParsedQueryParams

  describe "input_date_range -> period (+ from, to)" do
    for input_date_range <- [:realtime, :day, :month, :year, :all] do
      test "serializes #{input_date_range} input_date_range" do
        serialized = serialize(%ParsedQueryParams{input_date_range: unquote(input_date_range)})
        assert serialized == "?period=#{Atom.to_string(unquote(input_date_range))}"
      end
    end

    for i <- [7, 28, 30, 91] do
      test "serializes {:last_n_days, #{i}} input_date_range" do
        serialized = serialize(%ParsedQueryParams{input_date_range: {:last_n_days, unquote(i)}})
        assert serialized == "?period=#{unquote(i)}d"
      end
    end

    for i <- [6, 12] do
      test "serializes {:last_n_months, #{i}} input_date_range" do
        serialized = serialize(%ParsedQueryParams{input_date_range: {:last_n_months, unquote(i)}})
        assert serialized == "?period=#{unquote(i)}mo"
      end
    end

    test "serlializes custom input_date_range" do
      serialized =
        serialize(%ParsedQueryParams{
          input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-03-05]}
        })

      assert serialized == "?period=custom&from=2021-01-01&to=2021-03-05"
    end
  end

  describe "relative_date -> date" do
    test "serializes a date struct into iso8601" do
      serialized = serialize(%ParsedQueryParams{relative_date: ~D[2021-05-05]})
      assert serialized == "?date=2021-05-05"
    end
  end

  describe "filters" do
    test "serializes multiple filters" do
      serialized =
        serialize(%ParsedQueryParams{
          filters: [
            [:is, "visit:exit_page", ["/:dashboard"]],
            [:is, "visit:source", ["Bing"]],
            [:is, "event:props:theme", ["system"]]
          ]
        })

      assert serialized == "?f=is,exit_page,/:dashboard&f=is,source,Bing&f=is,props:theme,system"
    end

    test "serializes empty filters" do
      serialized = serialize(%ParsedQueryParams{filters: []})
      assert serialized == ""
    end
  end
end
