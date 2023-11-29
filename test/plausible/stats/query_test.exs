defmodule Plausible.Stats.QueryTest do
  use Plausible.DataCase, async: true
  alias Plausible.Stats.Query

  setup do
    user = insert(:user)

    site =
      insert(:site,
        members: [user],
        inserted_at: ~N[2020-01-01T00:00:00],
        stats_start_date: ~D[2020-01-01]
      )

    {:ok, site: site, user: user}
  end

  test "parses day format", %{site: site} do
    q = Query.from(site, %{"period" => "day", "date" => "2019-01-01"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-01]
    assert q.interval == "hour"
  end

  test "day format defaults to today", %{site: site} do
    q = Query.from(site, %{"period" => "day"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.interval == "hour"
  end

  test "parses realtime format", %{site: site} do
    q = Query.from(site, %{"period" => "realtime"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.period == "realtime"
  end

  test "parses month format", %{site: site} do
    q = Query.from(site, %{"period" => "month", "date" => "2019-01-01"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-31]
    assert q.interval == "date"
  end

  test "parses 6 month format", %{site: site} do
    q = Query.from(site, %{"period" => "6mo"})

    assert q.date_range.first ==
             Timex.shift(Timex.today(), months: -5) |> Timex.beginning_of_month()

    assert q.date_range.last == Timex.today() |> Timex.end_of_month()
    assert q.interval == "month"
  end

  test "parses 12 month format", %{site: site} do
    q = Query.from(site, %{"period" => "12mo"})

    assert q.date_range.first ==
             Timex.shift(Timex.today(), months: -11) |> Timex.beginning_of_month()

    assert q.date_range.last == Timex.today() |> Timex.end_of_month()
    assert q.interval == "month"
  end

  test "parses year to date format", %{site: site} do
    q = Query.from(site, %{"period" => "year"})

    assert q.date_range.first ==
             Timex.now(site.timezone) |> Timex.to_date() |> Timex.beginning_of_year()

    assert q.date_range.last ==
             Timex.now(site.timezone) |> Timex.to_date() |> Timex.end_of_year()

    assert q.interval == "month"
  end

  test "parses all time", %{site: site} do
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == NaiveDateTime.to_date(site.inserted_at)
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "month"
  end

  test "parses all time in correct timezone", %{site: site} do
    site = Map.put(site, :timezone, "America/Cancun")
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == ~D[2019-12-31]
    assert q.date_range.last == Timex.today("America/Cancun")
  end

  test "all time shows today if site has no start date", %{site: site} do
    site = Map.put(site, :stats_start_date, nil)
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "hour"
  end

  test "all time shows hourly if site is completely new", %{site: site} do
    site = Map.put(site, :stats_start_date, Timex.now())
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == Timex.today()
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "hour"
  end

  test "all time shows daily if site is more than a day old", %{site: site} do
    site = Map.put(site, :stats_start_date, Timex.now() |> Timex.shift(days: -1))
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == Timex.today() |> Timex.shift(days: -1)
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "date"
  end

  test "all time shows monthly if site is more than a month old", %{site: site} do
    site = Map.put(site, :stats_start_date, Timex.now() |> Timex.shift(months: -1))
    q = Query.from(site, %{"period" => "all"})

    assert q.date_range.first == Timex.today() |> Timex.shift(months: -1)
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "month"
  end

  test "all time uses passed interval different from the default interval", %{site: site} do
    site = Map.put(site, :stats_start_date, Timex.now() |> Timex.shift(months: -1))
    q = Query.from(site, %{"period" => "all", "interval" => "week"})

    assert q.date_range.first == Timex.today() |> Timex.shift(months: -1)
    assert q.date_range.last == Timex.today()
    assert q.period == "all"
    assert q.interval == "week"
  end

  test "defaults to 30 days format", %{site: site} do
    assert Query.from(site, %{}) == Query.from(site, %{"period" => "30d"})
  end

  test "parses custom format", %{site: site} do
    q = Query.from(site, %{"period" => "custom", "from" => "2019-01-01", "to" => "2019-01-15"})

    assert q.date_range.first == ~D[2019-01-01]
    assert q.date_range.last == ~D[2019-01-15]
    assert q.interval == "date"
  end

  @tag :full_build_only
  test "adds sample_threshold :infinite to query struct", %{site: site} do
    q = Query.from(site, %{"period" => "30d", "sample_threshold" => "infinite"})
    assert q.sample_threshold == :infinite
  end

  @tag :full_build_only
  test "casts sample_threshold to integer in query struct", %{site: site} do
    q = Query.from(site, %{"period" => "30d", "sample_threshold" => "30000000"})
    assert q.sample_threshold == 30_000_000
  end

  describe "filters" do
    test "parses goal filter", %{site: site} do
      filters = Jason.encode!(%{"goal" => "Signup"})
      q = Query.from(site, %{"period" => "6mo", "filters" => filters})

      assert q.filters["goal"] == "Signup"
    end

    test "parses source filter", %{site: site} do
      filters = Jason.encode!(%{"source" => "Twitter"})
      q = Query.from(site, %{"period" => "6mo", "filters" => filters})

      assert q.filters["source"] == "Twitter"
    end

    test "allows prop filters when site owner is on a business plan", %{site: site, user: user} do
      insert(:business_subscription, user: user)
      filters = Jason.encode!(%{"props" => %{"author" => "!John Doe"}})
      query = Query.from(site, %{"period" => "6mo", "filters" => filters})

      assert Map.has_key?(query.filters, "props")
    end

    test "drops prop filter when site owner is on a growth plan", %{site: site, user: user} do
      insert(:growth_subscription, user: user)
      filters = Jason.encode!(%{"props" => %{"author" => "!John Doe"}})
      query = Query.from(site, %{"period" => "6mo", "filters" => filters})

      refute Map.has_key?(query.filters, "props")
    end
  end
end
