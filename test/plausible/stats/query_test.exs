defmodule Plausible.Stats.QueryTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.Query

  @tz "UTC"

  test "parses 24h format" do
    q = Query.from(@tz, %{"period" => "24h"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.step_type == "hour"
  end

  test "parses 7d format" do
    q = Query.from(@tz, %{"period" => "7d"})

    assert q.date_range.first == Timex.shift(Timex.today(), days: -7)
    assert q.date_range.last == Timex.today()
    assert q.step_type == "date"
  end

  test "parses 30d format" do
    q = Query.from(@tz, %{"period" => "30d"})

    assert q.date_range.first == Timex.shift(Timex.today(), days: -30)
    assert q.date_range.last == Timex.today()
    assert q.step_type == "date"
  end

  test "defaults to 7d format" do
    assert Query.from(@tz, %{}) == Query.from(@tz, %{"period" => "7d"})
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
