defmodule Plausible.Stats.QueryTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.Query

  @tz "UTC"

  test "parses day format" do
    q = Query.from(@tz, %{"period" => "day", "date" => "2019-01-01"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-01]
    assert q.step_type == "hour"
  end

  test "day fromat defaults to today" do
    q = Query.from(@tz, %{"period" => "day"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.step_type == "hour"
  end


  test "parses month format" do
    q = Query.from(@tz, %{"period" => "month", "date" => "2019-01-01"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-31]
    assert q.step_type == "date"
  end

  test "parses 3 month format" do
    q = Query.from(@tz, %{"period" => "3mo"})

    assert q.date_range.first == Timex.shift(Timex.today(), months: -2) |> Timex.beginning_of_month()
    assert q.date_range.last == Timex.today()
    assert q.step_type == "month"
  end

  test "defaults to 6 months format" do
    assert Query.from(@tz, %{}) == Query.from(@tz, %{"period" => "6mo"})
  end

  test "parses custom format" do
    q = Query.from(@tz, %{
      "period" => "custom",
      "from" => "2019-01-01",
      "to" => "2019-02-01"
    })

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-02-01]
    assert q.step_type == "date"
  end
end
