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

  test "parses realtime format" do
    q = Query.from(@tz, %{"period" => "realtime"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.period == "realtime"
  end

  test "parses month format" do
    q = Query.from(@tz, %{"period" => "month", "date" => "2019-01-01"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-31]
    assert q.step_type == "date"
  end

  test "parses 6 month format" do
    q = Query.from(@tz, %{"period" => "6mo"})

    assert q.date_range.first ==
             Timex.shift(Timex.today(), months: -5) |> Timex.beginning_of_month()

    assert q.date_range.last == Timex.today()
    assert q.step_type == "month"
  end

  test "parses 12 month format" do
    q = Query.from(@tz, %{"period" => "12mo"})

    assert q.date_range.first ==
             Timex.shift(Timex.today(), months: -11) |> Timex.beginning_of_month()

    assert q.date_range.last == Timex.today()
    assert q.step_type == "month"
  end

  test "defaults to 30 days format" do
    assert Query.from(@tz, %{}) == Query.from(@tz, %{"period" => "30d"})
  end

  test "parses 60d format" do
    q = Query.from(@tz, %{"period" => "60d"})

    assert q.date_range.last == Timex.today()
    assert Timex.diff(q.date_range.last, q.date_range.first, :days) == 60
    assert q.step_type == "date"
  end

  test "parses custom format" do
    q = Query.from(@tz, %{"period" => "custom", "from" => "2019-01-01", "to" => "2019-01-15"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-15]
    assert q.step_type == "date"
  end

  describe "filters" do
    test "parses goal filter" do
      filters = Jason.encode!(%{"goal" => "Signup"})
      q = Query.from(@tz, %{"period" => "6mo", "filters" => filters})

      assert q.filters["goal"] == "Signup"
    end
  end
end
