defmodule Plausible.Stats.QueryTest do
  use Plausible.DataCase, async: true
  alias Plausible.Stats.{Query, NaiveDateTimeRange}

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

  @tag :slow
  test "keeps current timestamp so that utc_boundaries don't depend on time passing by", %{
    site: site
  } do
    q1 = %{now: %NaiveDateTime{}} = Query.from(site, %{"period" => "realtime"})
    q2 = %{now: %NaiveDateTime{}} = Query.from(site, %{"period" => "30m"})
    boundaries1 = Plausible.Stats.Time.utc_boundaries(q1, site)
    boundaries2 = Plausible.Stats.Time.utc_boundaries(q2, site)
    :timer.sleep(1500)
    assert ^boundaries1 = Plausible.Stats.Time.utc_boundaries(q1, site)
    assert ^boundaries2 = Plausible.Stats.Time.utc_boundaries(q2, site)
  end

  test "parses day format", %{site: site} do
    q = Query.from(site, %{"period" => "day", "date" => "2019-01-01"})

    assert q.date_range.first == ~N[2019-01-01 00:00:00]
    assert q.date_range.last == ~N[2019-01-02 00:00:00]
    assert q.interval == "hour"
  end

  test "day format defaults to today", %{site: site} do
    q = Query.from(site, %{"period" => "day"})

    expected_first_datetime = Date.utc_today() |> NaiveDateTime.new!(~T[00:00:00])
    expected_last_datetime = expected_first_datetime |> NaiveDateTime.shift(day: 1)

    assert q.date_range.first == expected_first_datetime
    assert q.date_range.last == expected_last_datetime
    assert q.interval == "hour"
  end

  test "parses realtime format", %{site: site} do
    q = Query.from(site, %{"period" => "realtime"})

    expected_first_datetime = q.now |> NaiveDateTime.shift(minute: -5)
    expected_last_datetime = q.now |> NaiveDateTime.shift(second: 5)

    assert q.date_range.first == expected_first_datetime
    assert q.date_range.last == expected_last_datetime
    assert q.period == "realtime"
  end

  test "parses month format", %{site: site} do
    q = Query.from(site, %{"period" => "month", "date" => "2019-01-01"})

    assert q.date_range.first == ~N[2019-01-01 00:00:00]
    assert q.date_range.last == ~N[2019-02-01 00:00:00]
    assert q.interval == "day"
  end

  test "parses 6 month format", %{site: site} do
    q = Query.from(site, %{"period" => "6mo"})

    expected_first_datetime =
      q.now
      |> NaiveDateTime.to_date()
      |> Date.shift(month: -5)
      |> Date.beginning_of_month()
      |> NaiveDateTime.new!(~T[00:00:00])

    expected_last_datetime =
      q.now
      |> NaiveDateTime.to_date()
      |> Date.end_of_month()
      |> Date.shift(day: 1)
      |> NaiveDateTime.new!(~T[00:00:00])

    assert q.date_range.first == expected_first_datetime
    assert q.date_range.last == expected_last_datetime
    assert q.interval == "month"
  end

  test "parses 12 month format", %{site: site} do
    q = Query.from(site, %{"period" => "12mo"})

    expected_first_datetime =
      q.now
      |> NaiveDateTime.to_date()
      |> Date.shift(month: -11)
      |> Date.beginning_of_month()
      |> NaiveDateTime.new!(~T[00:00:00])

    expected_last_datetime =
      q.now
      |> NaiveDateTime.to_date()
      |> Date.end_of_month()
      |> Date.shift(day: 1)
      |> NaiveDateTime.new!(~T[00:00:00])

    assert q.date_range.first == expected_first_datetime
    assert q.date_range.last == expected_last_datetime
    assert q.interval == "month"
  end

  test "parses year to date format", %{site: site} do
    q = Query.from(site, %{"period" => "year"})

    %Date{year: current_year} = NaiveDateTime.to_date(q.now)

    expected_first_datetime =
      Date.new!(current_year, 1, 1)
      |> NaiveDateTime.new!(~T[00:00:00])

    expected_last_datetime =
      NaiveDateTime.shift(expected_first_datetime, year: 1)

    assert q.date_range.first == expected_first_datetime
    assert q.date_range.last == expected_last_datetime
    assert q.interval == "month"
  end

  test "parses all time", %{site: site} do
    q = Query.from(site, %{"period" => "all"})

    expected_last_datetime =
      q.now
      |> NaiveDateTime.to_date()
      |> Date.shift(day: 1)
      |> NaiveDateTime.new!(~T[00:00:00])

    assert q.date_range.first == site.inserted_at
    assert q.date_range.last == expected_last_datetime
    assert q.period == "all"
    assert q.interval == "month"
  end

  test "parses all time in site timezone", %{site: site} do
    for timezone <- ["Etc/GMT+12", "Etc/GMT-12"] do
      site = Map.put(site, :timezone, timezone)
      query = Query.from(site, %{"period" => "all"})

      expected_first_datetime = ~N[2020-01-01 00:00:00]

      expected_last_datetime =
        Timex.today(timezone)
        |> Date.shift(day: 1)
        |> NaiveDateTime.new!(~T[00:00:00])

      assert query.date_range.first == expected_first_datetime
      assert query.date_range.last == expected_last_datetime
    end
  end

  test "all time shows today if site has no start date", %{site: site} do
    site = Map.put(site, :stats_start_date, nil)
    q = Query.from(site, %{"period" => "all"})

    today = Date.utc_today()

    assert q.date_range == NaiveDateTimeRange.new!(today, today)
    assert q.period == "all"
    assert q.interval == "hour"
  end

  test "all time shows hourly if site is completely new", %{site: site} do
    site = Map.put(site, :stats_start_date, Date.utc_today())
    q = Query.from(site, %{"period" => "all"})

    today = Date.utc_today()

    assert q.date_range == NaiveDateTimeRange.new!(today, today)
    assert q.period == "all"
    assert q.interval == "hour"
  end

  test "all time shows daily if site is more than a day old", %{site: site} do
    today = Date.utc_today()
    yesterday = today |> Date.shift(day: -1)

    site = Map.put(site, :stats_start_date, yesterday)

    q = Query.from(site, %{"period" => "all"})

    assert q.date_range == NaiveDateTimeRange.new!(yesterday, today)
    assert q.period == "all"
    assert q.interval == "day"
  end

  test "all time shows monthly if site is more than a month old", %{site: site} do
    today = Date.utc_today()
    last_month = today |> Date.shift(month: -1)

    site = Map.put(site, :stats_start_date, last_month)

    q = Query.from(site, %{"period" => "all"})

    assert q.date_range == NaiveDateTimeRange.new!(last_month, today)
    assert q.period == "all"
    assert q.interval == "month"
  end

  test "all time uses passed interval different from the default interval", %{site: site} do
    today = Date.utc_today()
    last_month = today |> Date.shift(month: -1)

    site = Map.put(site, :stats_start_date, last_month)

    q = Query.from(site, %{"period" => "all", "interval" => "week"})

    assert q.date_range == NaiveDateTimeRange.new!(last_month, today)
    assert q.period == "all"
    assert q.interval == "week"
  end

  test "defaults to 30 days format", %{site: site} do
    assert Query.from(site, %{}) == Query.from(site, %{"period" => "30d"})
  end

  test "parses custom format", %{site: site} do
    q = Query.from(site, %{"period" => "custom", "from" => "2019-01-01", "to" => "2019-01-15"})

    assert q.date_range.first == ~N[2019-01-01 00:00:00]
    assert q.date_range.last == ~N[2019-01-16 00:00:00]
    assert q.interval == "day"
  end

  @tag :ee_only
  test "adds sample_threshold :infinite to query struct", %{site: site} do
    q = Query.from(site, %{"period" => "30d", "sample_threshold" => "infinite"})
    assert q.sample_threshold == :infinite
  end

  @tag :ee_only
  test "casts sample_threshold to integer in query struct", %{site: site} do
    q = Query.from(site, %{"period" => "30d", "sample_threshold" => "30000000"})
    assert q.sample_threshold == 30_000_000
  end

  describe "filters" do
    test "parses goal filter", %{site: site} do
      filters = Jason.encode!(%{"goal" => "Signup"})
      q = Query.from(site, %{"period" => "6mo", "filters" => filters})

      assert q.filters == [[:is, "event:goal", ["Signup"]]]
    end

    test "parses source filter", %{site: site} do
      filters = Jason.encode!(%{"source" => "Twitter"})
      q = Query.from(site, %{"period" => "6mo", "filters" => filters})

      assert q.filters == [[:is, "visit:source", ["Twitter"]]]
    end
  end

  describe "include_imported" do
    setup [:create_site]

    test "is true when requested via params and imported data exists", %{site: site} do
      insert(:site_import, site: site)
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: true} =
               Query.from(site, %{"period" => "day", "with_imported" => "true"})
    end

    test "is false when imported data does not exist", %{site: site} do
      assert %{include_imported: false, skip_imported_reason: :no_imported_data} =
               Query.from(site, %{"period" => "day", "with_imported" => "true"})
    end

    test "is false when imported data exists but is out of the date range", %{site: site} do
      insert(:site_import, site: site, start_date: ~D[2021-01-01], end_date: ~D[2022-01-01])
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false, skip_imported_reason: :out_of_range} =
               Query.from(site, %{"period" => "day", "with_imported" => "true"})
    end

    test "is false in realtime even when imported data from today exists", %{site: site} do
      insert(:site_import, site: site)
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false, skip_imported_reason: :unsupported_query} =
               Query.from(site, %{"period" => "realtime", "with_imported" => "true"})
    end

    test "is false when an arbitrary custom property filter is used", %{site: site} do
      insert(:site_import, site: site)
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false, skip_imported_reason: :unsupported_query} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => "event:props:url",
                 "filters" => Jason.encode!(%{"props" => %{"author" => "!John Doe"}})
               })
    end

    test "is true when breaking down by url and filtering by outbound link or file download goal",
         %{site: site} do
      insert(:site_import, site: site)
      site = Plausible.Imported.load_import_data(site)

      Enum.each(["Outbound Link: Click", "File Download"], fn goal_name ->
        insert(:goal, site: site, event_name: goal_name)

        assert %{include_imported: true} =
                 Query.from(site, %{
                   "period" => "day",
                   "with_imported" => "true",
                   "property" => "event:props:url",
                   "filters" => Jason.encode!(%{"goal" => goal_name})
                 })
      end)
    end

    test "is false when breaking down by url but without a special goal filter",
         %{site: site} do
      insert(:site_import, site: site)
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => "event:props:url"
               })
    end

    test "is false when breaking down by url but with a mismatched special goal filter",
         %{site: site} do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "404")
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => "event:props:url",
                 "filters" => Jason.encode!(%{"goal" => "404"})
               })
    end

    test "is false when breaking down by url but with a special goal filter and an arbitrary filter",
         %{site: site} do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => "event:props:url",
                 "filters" =>
                   Jason.encode!(%{"goal" => "Outbound Link: Click", "page" => "/example"})
               })
    end

    for property <- [nil, "event:goal", "event:name"] do
      test "is true when filtering by custom prop and special goal when breakdown prop is #{property}",
           %{site: site} do
        insert(:site_import, site: site)
        insert(:goal, site: site, event_name: "Outbound Link: Click")
        site = Plausible.Imported.load_import_data(site)

        assert %{include_imported: true} =
                 Query.from(site, %{
                   "period" => "day",
                   "with_imported" => "true",
                   "property" => unquote(property),
                   "filters" =>
                     Jason.encode!(%{
                       "goal" => "Outbound Link: Click",
                       "props" => %{"url" => "https://example.com"}
                     })
                 })
      end
    end

    test "is true when filtering by matching multiple custom prop values and special goal", %{
      site: site
    } do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: true} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => nil,
                 "filters" =>
                   Jason.encode!(%{
                     "goal" => "Outbound Link: Click",
                     "props" => %{"url" => "https://example.com|https://another.example.com"}
                   })
               })
    end

    test "is false when filtering by mismatched custom prop values and special goal", %{
      site: site
    } do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => nil,
                 "filters" =>
                   Jason.encode!(%{
                     "goal" => "Outbound Link: Click",
                     "props" => %{"url" => "https://example.com", "path" => "/whatever"}
                   })
               })
    end

    test "is false with a custom prop + mismatched special goal filter",
         %{site: site} do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "404")
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => nil,
                 "filters" =>
                   Jason.encode!(%{"goal" => "404", "props" => %{"url" => "https://example.com"}})
               })
    end

    test "is false with a custom prop + required goal + arbitrary filter",
         %{site: site} do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => nil,
                 "filters" =>
                   Jason.encode!(%{
                     "goal" => "Outbound Link: Click",
                     "page" => "/example",
                     "props" => %{"url" => "https://example.com"}
                   })
               })
    end

    test "is false with a custom prop filter and non-matching property", %{site: site} do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")
      site = Plausible.Imported.load_import_data(site)

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => "visit:source",
                 "filters" =>
                   Jason.encode!(%{
                     "goal" => "Outbound Link: Click",
                     "props" => %{"url" => "https://example.com"}
                   })
               })
    end
  end
end
