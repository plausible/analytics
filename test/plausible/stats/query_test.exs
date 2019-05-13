defmodule Plausible.Stats.QueryTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.Query

  @tz "UTC"

  test "parses day format" do
    q = Query.from(@tz, %{"period" => "day"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.step_type == "hour"
  end

  test "parses week format" do
    q = Query.from(@tz, %{"period" => "week"})

    assert q.date_range.first == Timex.shift(Timex.today(), days: -7)
    assert q.date_range.last == Timex.today()
    assert q.step_type == "date"
  end

  test "parses month format" do
    q = Query.from(@tz, %{"period" => "month"})

    assert q.date_range.first == Timex.shift(Timex.today(), days: -30)
    assert q.date_range.last == Timex.today()
    assert q.step_type == "date"
  end

  test "defaults to month format" do
    assert Query.from(@tz, %{}) == Query.from(@tz, %{"period" => "month"})
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
