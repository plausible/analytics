defmodule Plausible.Stats.QueryTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.Query

  @site_inserted_at ~D[2020-01-01]
  @site %Plausible.Site{
    timezone: "UTC",
    inserted_at: @site_inserted_at,
    stats_start_date: @site_inserted_at
  }

  test "parses day format" do
    q = Query.from(@site, %{"period" => "day", "date" => "2019-01-01"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-01]
    assert q.interval == "hour"
  end

  test "day format defaults to today" do
    q = Query.from(@site, %{"period" => "day"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.interval == "hour"
  end

  test "parses realtime format" do
    q = Query.from(@site, %{"period" => "realtime"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.period == "realtime"
  end

  test "parses month format" do
    q = Query.from(@site, %{"period" => "month", "date" => "2019-01-01"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-31]
    assert q.interval == "date"
  end

  test "parses 6 month format" do
    q = Query.from(@site, %{"period" => "6mo"})

    assert q.date_range.first ==
             Timex.shift(Timex.today(), months: -5) |> Timex.beginning_of_month()

    assert q.date_range.last == Timex.today() |> Timex.end_of_month()
    assert q.interval == "month"
  end

  test "parses 12 month format" do
    q = Query.from(@site, %{"period" => "12mo"})

    assert q.date_range.first ==
             Timex.shift(Timex.today(), months: -11) |> Timex.beginning_of_month()

    assert q.date_range.last == Timex.today() |> Timex.end_of_month()
    assert q.interval == "month"
  end

  test "parses year to date format" do
    q = Query.from(@site, %{"period" => "year"})

    assert q.date_range.first ==
             Timex.now(@site.timezone) |> Timex.to_date() |> Timex.beginning_of_year()

    assert q.date_range.last ==
             Timex.now(@site.timezone) |> Timex.to_date() |> Timex.end_of_year()

    assert q.interval == "month"
  end

  test "parses all time" do
    q = Query.from(@site, %{"period" => "all"})

    assert q.date_range.first == @site_inserted_at
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "month"
  end

  test "parses all time in correct timezone" do
    site = Map.put(@site, :timezone, "America/Cancun")
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == ~D[2019-12-31]
    assert q.date_range.last == Timex.today("America/Cancun")
  end

  test "all time shows today if site has no start date" do
    site = Map.put(@site, :stats_start_date, nil)
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "hour"
  end

  test "all time shows hourly if site is completely new" do
    site = Map.put(@site, :stats_start_date, Timex.now())
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "hour"
  end

  test "all time shows daily if site is more than a day old" do
    site = Map.put(@site, :stats_start_date, Timex.now() |> Timex.shift(days: -1))
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == Timex.today() |> Timex.shift(days: -1)
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "date"
  end

  test "all time shows monthly if site is more than a month old" do
    site = Map.put(@site, :stats_start_date, Timex.now() |> Timex.shift(months: -1))
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == Timex.today() |> Timex.shift(months: -1)
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "month"
  end

  test "all time uses passed interval different from the default interval" do
    site = Map.put(@site, :stats_start_date, Timex.now() |> Timex.shift(months: -1))
    q = Query.from(site, %{"period" => "all", "interval" => "week"})

    assert q.date_range.first == Timex.today() |> Timex.shift(months: -1)
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "week"
  end

  test "defaults to 30 days format" do
    assert Query.from(@site, %{}) == Query.from(@site, %{"period" => "30d"})
  end

  test "parses custom format" do
    q = Query.from(@site, %{"period" => "custom", "from" => "2019-01-01", "to" => "2019-01-15"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-15]
    assert q.interval == "date"
  end

  test "adds sample_threshold :infinite to query struct" do
    q = Query.from(@site, %{"period" => "30d", "sample_threshold" => "infinite"})
    assert q.sample_threshold == :infinite
  end

  test "casts sample_threshold to integer in query struct" do
    q = Query.from(@site, %{"period" => "30d", "sample_threshold" => "30000000"})
    assert q.sample_threshold == 30_000_000
  end

  describe "filters" do
    test "parses goal filter" do
      filters = Jason.encode!(%{"goal" => "Signup"})
      q = Query.from(@site, %{"period" => "6mo", "filters" => filters})

      assert q.filters["goal"] == "Signup"
    end

    test "parses source filter" do
      filters = Jason.encode!(%{"source" => "Twitter"})
      q = Query.from(@site, %{"period" => "6mo", "filters" => filters})

      assert q.filters["source"] == "Twitter"
    end
  end
end
