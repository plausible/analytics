defmodule Plausible.Stats.QueryTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test
  alias Plausible.Stats.Query
  alias Plausible.Stats.Legacy.QueryBuilder
  alias Plausible.Stats.DateTimeRange

  doctest Plausible.Stats.Legacy.QueryBuilder

  setup do
    user = new_user()

    site =
      new_site(
        owner: user,
        inserted_at: ~N[2020-01-01T00:00:00],
        stats_start_date: ~D[2020-01-01],
        timezone: "US/Eastern"
      )

    {:ok, site: site, user: user}
  end

  @now ~U[2024-05-03 16:30:00Z]

  @tag :slow
  test "keeps current timestamp so that utc_boundaries don't depend on time passing by", %{
    site: site
  } do
    q1 = %{now: %DateTime{}} = Query.from(site, %{"period" => "realtime"})
    q2 = %{now: %DateTime{}} = Query.from(site, %{"period" => "30m"})
    boundaries1 = Plausible.Stats.Time.utc_boundaries(q1)
    boundaries2 = Plausible.Stats.Time.utc_boundaries(q2)
    :timer.sleep(1500)
    assert ^boundaries1 = Plausible.Stats.Time.utc_boundaries(q1)
    assert ^boundaries2 = Plausible.Stats.Time.utc_boundaries(q2)
  end

  test "parses day format", %{site: site} do
    q = Query.from(site, %{"period" => "day", "date" => "2019-01-01"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2019-01-01 05:00:00Z]
    assert q.utc_time_range.last == ~U[2019-01-02 04:59:59Z]
    assert q.interval == "hour"
  end

  test "day format defaults to today", %{site: site} do
    q = Query.from(site, %{"period" => "day"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2024-05-03 04:00:00Z]
    assert q.utc_time_range.last == ~U[2024-05-04 03:59:59Z]
    assert q.interval == "hour"
  end

  test "parses realtime format", %{site: site} do
    q = Query.from(site, %{"period" => "realtime"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2024-05-03 16:25:00Z]
    assert q.utc_time_range.last == ~U[2024-05-03 16:30:05Z]
    assert q.period == "realtime"
  end

  test "parses month format", %{site: site} do
    q = Query.from(site, %{"period" => "month", "date" => "2019-01-01"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2019-01-01 05:00:00Z]
    assert q.utc_time_range.last == ~U[2019-02-01 04:59:59Z]
    assert q.interval == "day"
  end

  test "parses 6 month format", %{site: site} do
    q = Query.from(site, %{"period" => "6mo"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2023-12-01 05:00:00Z]
    assert q.utc_time_range.last == ~U[2024-06-01 03:59:59Z]
    assert q.interval == "month"
  end

  test "parses 12 month format", %{site: site} do
    q = Query.from(site, %{"period" => "12mo"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2023-06-01 04:00:00Z]
    assert q.utc_time_range.last == ~U[2024-06-01 03:59:59Z]
    assert q.interval == "month"
  end

  test "parses year to date format", %{site: site} do
    q = Query.from(site, %{"period" => "year"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2024-01-01 05:00:00Z]
    assert q.utc_time_range.last == ~U[2025-01-01 04:59:59Z]
    assert q.interval == "month"
  end

  test "parses all time", %{site: site} do
    q = Query.from(site, %{"period" => "all"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2020-01-01 05:00:00Z]
    assert q.utc_time_range.last == ~U[2024-05-04 03:59:59Z]
    assert q.period == "all"
    assert q.interval == "month"
  end

  test "parses all time in GMT+12 timezone", %{site: site} do
    site = Map.put(site, :timezone, "Etc/GMT+12")
    q = Query.from(site, %{"period" => "all"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2020-01-01 12:00:00Z]
    assert q.utc_time_range.last == ~U[2024-05-04 11:59:59Z]
  end

  test "all time shows today if site has no start date", %{site: site} do
    site = Map.put(site, :stats_start_date, nil)
    q = Query.from(site, %{"period" => "all"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2024-05-03 04:00:00Z]
    assert q.utc_time_range.last == ~U[2024-05-04 03:59:59Z]
    assert q.period == "all"
    assert q.interval == "hour"
  end

  test "all time shows hourly if site is completely new", %{site: site} do
    site = Map.put(site, :stats_start_date, @now |> DateTime.to_date())
    q = Query.from(site, %{"period" => "all"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2024-05-03 04:00:00Z]
    assert q.utc_time_range.last == ~U[2024-05-04 03:59:59Z]
    assert q.period == "all"
    assert q.interval == "hour"
  end

  test "all time shows daily if site is more than a day old", %{site: site} do
    yesterday = @now |> DateTime.to_date() |> Date.shift(day: -1)
    site = Map.put(site, :stats_start_date, yesterday)

    q = Query.from(site, %{"period" => "all"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2024-05-02 04:00:00Z]
    assert q.utc_time_range.last == ~U[2024-05-04 03:59:59Z]
    assert q.period == "all"
    assert q.interval == "day"
  end

  test "all time shows monthly if site is more than a month old", %{site: site} do
    last_month = @now |> DateTime.to_date() |> Date.shift(month: -1)
    site = Map.put(site, :stats_start_date, last_month)

    q = Query.from(site, %{"period" => "all"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2024-04-03 04:00:00Z]
    assert q.utc_time_range.last == ~U[2024-05-04 03:59:59Z]
    assert q.period == "all"
    assert q.interval == "month"
  end

  test "all time uses passed interval different from the default interval", %{site: site} do
    last_month = @now |> DateTime.to_date() |> Date.shift(month: -1)
    site = Map.put(site, :stats_start_date, last_month)

    q = Query.from(site, %{"period" => "all", "interval" => "week"}, %{}, @now)

    assert q.utc_time_range.first == ~U[2024-04-03 04:00:00Z]
    assert q.utc_time_range.last == ~U[2024-05-04 03:59:59Z]
    assert q.period == "all"
    assert q.interval == "week"
  end

  test "defaults to 30 days format", %{site: site} do
    assert Query.from(site, %{}) == Query.from(site, %{"period" => "30d"})
  end

  test "parses custom format", %{site: site} do
    q =
      Query.from(
        site,
        %{"period" => "custom", "from" => "2019-01-01", "to" => "2019-01-15"},
        %{},
        @now
      )

    assert q.utc_time_range.first == ~U[2019-01-01 05:00:00Z]
    assert q.utc_time_range.last == ~U[2019-01-16 04:59:59Z]
    assert q.interval == "day"
  end

  @tag :ee_only
  test "adds sample_threshold :no_sampling to query struct", %{site: site} do
    q = Query.from(site, %{"period" => "30d", "sample_threshold" => "infinite"})
    assert q.sample_threshold == :no_sampling
  end

  @tag :ee_only
  test "casts sample_threshold to integer in query struct", %{site: site} do
    q = Query.from(site, %{"period" => "30d", "sample_threshold" => "30000000"})
    assert q.sample_threshold == 30_000_000
  end

  describe "&date_range/2" do
    defp date_range({first, last}, timezone, now \\ nil, opts \\ []) do
      %Query{
        utc_time_range: DateTimeRange.new!(first, last),
        timezone: timezone,
        now: now || last
      }
      |> Query.date_range(opts)
    end

    test "with no options" do
      assert date_range({~U[2024-05-05 00:00:00Z], ~U[2024-05-07 23:59:59Z]}, "Etc/UTC") ==
               Date.range(~D[2024-05-05], ~D[2024-05-07])

      assert date_range({~U[2024-05-05 12:00:00Z], ~U[2024-05-08 11:59:59Z]}, "Etc/GMT+12") ==
               Date.range(~D[2024-05-05], ~D[2024-05-07])

      assert date_range({~U[2024-05-04 12:00:00Z], ~U[2024-05-07 11:59:59Z]}, "Etc/GMT-12") ==
               Date.range(~D[2024-05-05], ~D[2024-05-07])
    end

    test "trim_trailing: true" do
      assert date_range(
               {~U[2024-05-05 00:00:00Z], ~U[2024-05-07 23:59:59Z]},
               "Etc/UTC",
               ~U[2024-05-08 12:00:00Z],
               trim_trailing: true
             ) == Date.range(~D[2024-05-05], ~D[2024-05-07])

      assert date_range(
               {~U[2024-05-05 00:00:00Z], ~U[2024-05-07 23:59:59Z]},
               "Etc/UTC",
               ~U[2024-05-07 12:00:00Z],
               trim_trailing: true
             ) == Date.range(~D[2024-05-05], ~D[2024-05-07])

      assert date_range(
               {~U[2024-05-05 00:00:00Z], ~U[2024-05-07 23:59:59Z]},
               "Etc/UTC",
               ~U[2024-05-06 12:00:00Z],
               trim_trailing: true
             ) == Date.range(~D[2024-05-05], ~D[2024-05-06])

      assert date_range(
               {~U[2024-05-05 12:00:00Z], ~U[2024-05-08 11:59:59Z]},
               "Etc/GMT+12",
               ~U[2024-05-09 00:00:00Z],
               trim_trailing: true
             ) == Date.range(~D[2024-05-05], ~D[2024-05-07])

      assert date_range(
               {~U[2024-05-05 12:00:00Z], ~U[2024-05-08 11:59:59Z]},
               "Etc/GMT+12",
               ~U[2024-05-07 07:00:00Z],
               trim_trailing: true
             ) == Date.range(~D[2024-05-05], ~D[2024-05-06])

      assert date_range(
               {~U[2024-05-05 12:00:00Z], ~U[2024-05-08 11:59:59Z]},
               "Etc/GMT+12",
               ~U[2024-05-03 07:00:00Z],
               trim_trailing: true
             ) == Date.range(~D[2024-05-05], ~D[2024-05-05])
    end
  end

  describe "include_imported" do
    setup [:create_site]

    test "is true when requested via params and imported data exists", %{site: site} do
      insert(:site_import, site: site)

      assert %{include_imported: true} =
               Query.from(site, %{"period" => "day", "with_imported" => "true"})
    end

    test "is false when imported data does not exist", %{site: site} do
      assert %{include_imported: false, skip_imported_reason: :no_imported_data} =
               Query.from(site, %{"period" => "day", "with_imported" => "true"})
    end

    test "is false when imported data exists but is out of the date range", %{site: site} do
      insert(:site_import, site: site, start_date: ~D[2021-01-01], end_date: ~D[2022-01-01])

      assert %{include_imported: false, skip_imported_reason: :out_of_range} =
               Query.from(site, %{"period" => "day", "with_imported" => "true"})
    end

    test "is false in realtime even when imported data from today exists", %{site: site} do
      insert(:site_import, site: site)

      assert %{include_imported: false, skip_imported_reason: :unsupported_query} =
               Query.from(site, %{"period" => "realtime", "with_imported" => "true"})
    end

    test "is false when an arbitrary custom property filter is used", %{site: site} do
      insert(:site_import, site: site)

      assert %{include_imported: false, skip_imported_reason: :unsupported_query} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => "event:props:url",
                 "filters" => Jason.encode!([[:is_not, "event:props:author", ["John Doe"]]])
               })
    end

    test "is true when breaking down by url and filtering by outbound link or file download goal",
         %{site: site} do
      insert(:site_import, site: site)

      Enum.each(["Outbound Link: Click", "File Download"], fn goal_name ->
        insert(:goal, site: site, event_name: goal_name)

        assert %{include_imported: true} =
                 Query.from(site, %{
                   "period" => "day",
                   "with_imported" => "true",
                   "property" => "event:props:url",
                   "filters" => Jason.encode!([[:is, "event:goal", [goal_name]]])
                 })
      end)
    end

    test "is false when breaking down by url but without a special goal filter",
         %{site: site} do
      insert(:site_import, site: site)

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

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => "event:props:url",
                 "filters" => Jason.encode!([[:is, "event:goal", ["404"]]])
               })
    end

    test "is false when breaking down by url but with a special goal filter and an arbitrary filter",
         %{site: site} do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => "event:props:url",
                 "filters" =>
                   Jason.encode!([
                     [:is, "event:goal", ["Outbound Link: Click"]],
                     [:is, "event:page", ["/example"]]
                   ])
               })
    end

    for property <- [nil, "event:goal", "event:name"] do
      test "is true when filtering by custom prop and special goal when breakdown prop is #{property}",
           %{site: site} do
        insert(:site_import, site: site)
        insert(:goal, site: site, event_name: "Outbound Link: Click")

        assert %{include_imported: true} =
                 Query.from(site, %{
                   "period" => "day",
                   "with_imported" => "true",
                   "property" => unquote(property),
                   "filters" =>
                     Jason.encode!([
                       [:is, "event:goal", ["Outbound Link: Click"]],
                       [:is, "event:props:url", ["https://example.com"]]
                     ])
                 })
      end
    end

    test "is true when filtering by matching multiple custom prop values and special goal", %{
      site: site
    } do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")

      assert %{include_imported: true} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => nil,
                 "filters" =>
                   Jason.encode!([
                     [:is, "event:goal", ["Outbound Link: Click"]],
                     [
                       :is,
                       "event:props:url",
                       ["https://example.com", "https://another.example.com"]
                     ]
                   ])
               })
    end

    test "is false when filtering by mismatched custom prop values and special goal", %{
      site: site
    } do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => nil,
                 "filters" =>
                   Jason.encode!([
                     [:is, "event:goal", ["Outbound Link: Click"]],
                     [:is, "event:props:url", ["https://example.com"]],
                     [:is, "event:props:path", ["/whatever"]]
                   ])
               })
    end

    test "is false with a custom prop + mismatched special goal filter",
         %{site: site} do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "404")

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => nil,
                 "filters" =>
                   Jason.encode!([
                     [:is, "event:goal", ["404"]],
                     [:is, "event:props:url", ["https://example.com"]]
                   ])
               })
    end

    test "is false with a custom prop + required goal + arbitrary filter",
         %{site: site} do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => nil,
                 "filters" =>
                   Jason.encode!([
                     [:is, "event:goal", ["Outbound Link: Click"]],
                     [:is, "event:page", ["/example"]],
                     [:is, "event:props:url", ["https://example.com"]]
                   ])
               })
    end

    test "is false with a custom prop filter and non-matching property", %{site: site} do
      insert(:site_import, site: site)
      insert(:goal, site: site, event_name: "Outbound Link: Click")

      assert %{include_imported: false} =
               Query.from(site, %{
                 "period" => "day",
                 "with_imported" => "true",
                 "property" => "visit:source",
                 "filters" =>
                   Jason.encode!([
                     [:is, "event:goal", ["Outbound Link: Click"]],
                     [:is, "event:props:url", ["https://example.com"]]
                   ])
               })
    end
  end
end
