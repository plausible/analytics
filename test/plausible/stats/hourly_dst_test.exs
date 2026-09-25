defmodule Plausible.Stats.HourlyDSTTest do
  use Plausible.DataCase

  alias Plausible.Stats
  alias Plausible.Stats.{DateTimeRange, QueryBuilder, Time}

  setup [:create_user, :create_site]

  test "sparse fall-back rows map to the correct occurrence", %{site: site} do
    site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "America/New_York"))
    populate_stats(site, [build(:pageview, timestamp: ~N[2024-11-03 06:30:00])])

    result = Stats.query(site, hourly_query(site, ~D[2024-11-03], ~D[2024-11-03]))

    assert result.results == [%{dimensions: ["2024-11-03 01:00:00"], metrics: [1]}]
    assert length(result.meta[:time_labels]) == 25
    assert Enum.slice(result.meta[:time_label_result_indices], 1, 2) == [nil, 0]
  end

  test "legacy, sparkline and CSV responses preserve sparse repeated hours", %{site: site} do
    site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "America/New_York"))
    populate_stats(site, [build(:pageview, timestamp: ~N[2024-11-03 06:30:00])])

    {legacy_rows, _meta} =
      Stats.Legacy.Timeseries.timeseries(
        site,
        hourly_query(site, ~D[2024-11-03], ~D[2024-11-03]),
        [:pageviews]
      )

    assert Enum.slice(legacy_rows, 1, 2) == [
             %{date: "2024-11-03 01:00:00", pageviews: 0},
             %{date: "2024-11-03 01:00:00", pageviews: 1}
           ]

    sparkline = Stats.Sparkline.overview_24h(site, ~N[2024-11-03 08:00:00])
    repeated = Enum.filter(sparkline.intervals, &(&1.interval == "2024-11-03 01:00:00"))

    assert repeated == [
             %{interval: "2024-11-03 01:00:00", visitors: 0},
             %{interval: "2024-11-03 01:00:00", visitors: 1}
           ]

    params = %{
      "date_range" => "day",
      "relative_date" => "2024-11-03",
      "filters" => [],
      "include" => %{},
      "reports" => %{
        "visitors.csv" => %{"dimensions" => ["time:hour"], "metrics" => ["pageviews"]}
      }
    }

    assert {:ok, [{~c"visitors.csv", csv}]} =
             Stats.Dashboard.CsvExport.get_csvs(site, params, %{})

    assert Enum.slice(NimbleCSV.RFC4180.parse_string(csv), 1, 2) == [
             ["2024-11-03 01:00:00", "0"],
             ["2024-11-03 01:00:00", "1"]
           ]
  end

  test "fall-back metrics remain distinct in events and smeared sessions", %{site: site} do
    site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "America/New_York"))

    populate_stats(site, [
      build(:pageview, timestamp: ~N[2024-11-03 05:30:00]),
      build(:pageview, timestamp: ~N[2024-11-03 06:30:00]),
      build(:pageview, timestamp: ~N[2024-11-03 06:45:00])
    ])

    query = hourly_query(site, ~D[2024-11-03], ~D[2024-11-03])
    query = Stats.Query.set(query, metrics: [:pageviews, :visits])
    result = Stats.query(site, query)

    assert result.results == [
             %{dimensions: ["2024-11-03 01:00:00"], metrics: [1, 1]},
             %{dimensions: ["2024-11-03 01:00:00"], metrics: [2, 2]}
           ]

    assert Enum.slice(result.meta[:time_label_result_indices], 1, 2) == [0, 1]
  end

  test "spring-forward retains the final hour without inventing a bucket", %{site: site} do
    site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "America/New_York"))
    populate_stats(site, [build(:pageview, timestamp: ~N[2024-03-11 03:30:00])])
    result = Stats.query(site, hourly_query(site, ~D[2024-03-10], ~D[2024-03-10]))

    assert length(result.meta[:time_labels]) == 23
    refute "2024-03-10 02:00:00" in result.meta[:time_labels]
    assert List.last(result.meta[:time_labels]) == "2024-03-10 23:00:00"
    assert List.last(result.meta[:time_label_result_indices]) == 0
    assert result.results == [%{dimensions: ["2024-03-10 23:00:00"], metrics: [1]}]
  end

  test "comparison aligns elapsed buckets and retains an unmatched final bucket", %{site: site} do
    site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "America/New_York"))

    populate_stats(site, [
      build(:pageview, timestamp: ~N[2024-11-04 06:30:00]),
      build(:pageview, timestamp: ~N[2024-11-04 07:30:00]),
      build(:pageview, timestamp: ~N[2024-11-04 07:45:00]),
      build(:pageview, timestamp: ~N[2024-11-03 05:30:00]),
      build(:pageview, timestamp: ~N[2024-11-03 06:30:00]),
      build(:pageview, timestamp: ~N[2024-11-04 04:30:00])
    ])

    query =
      hourly_query(site, ~D[2024-11-04], ~D[2024-11-04])
      |> Stats.Query.set_include(:compare, {:date_range, ~D[2024-11-03], ~D[2024-11-03]})
      |> QueryBuilder.put_comparison_utc_time_range()

    result = Stats.query(site, query)

    assert length(result.meta[:time_labels]) == 24
    assert length(result.meta[:comparison_time_labels]) == 25

    assert result.comparison_results == [
             %{dimensions: ["2024-11-03 01:00:00"], metrics: [1], change: [0]},
             %{dimensions: ["2024-11-03 01:00:00"], metrics: [1], change: [100]},
             %{dimensions: ["2024-11-03 23:00:00"], metrics: [1], change: nil}
           ]

    assert Enum.slice(result.meta[:comparison_time_label_result_indices], 1, 2) == [0, 1]
    assert List.last(result.meta[:comparison_time_label_result_indices]) == 2
  end

  test "nested comparison dimensions do not expose internal hour keys", %{site: site} do
    populate_stats(site, [build(:pageview, timestamp: ~N[2024-11-04 06:30:00])])

    query =
      hourly_query(site, ~D[2024-11-04], ~D[2024-11-04])
      |> Stats.Query.set(dimensions: ["time:hour", "event:page"])
      |> Stats.Query.set_include(:time_labels, false)
      |> Stats.Query.set_include(:compare, {:date_range, ~D[2024-11-03], ~D[2024-11-03]})
      |> QueryBuilder.put_comparison_utc_time_range()

    assert [row] = Stats.query(site, query).results
    assert ["2024-11-04 06:00:00", _page] = row.dimensions
    assert row.comparison.dimensions == row.dimensions
  end

  for {timezone, first, last} <- [
        {"America/New_York", ~D[2024-03-09], ~D[2024-03-11]},
        {"America/New_York", ~D[2024-11-02], ~D[2024-11-04]},
        {"Europe/Tallinn", ~D[2025-10-26], ~D[2025-10-26]},
        {"Pacific/Chatham", ~D[2024-04-07], ~D[2024-04-07]},
        {"Pacific/Chatham", ~D[2024-09-29], ~D[2024-09-29]},
        {"Australia/Lord_Howe", ~D[2024-10-06], ~D[2024-10-07]},
        {"Australia/Lord_Howe", ~D[2024-04-07], ~D[2024-04-08]},
        {"Asia/Kathmandu", ~D[2024-01-01], ~D[2024-01-01]}
      ] do
    @timezone timezone
    @first first
    @last last
    test "hourly spine matches ClickHouse buckets for #{timezone} #{@first}" do
      range = DateTimeRange.new!(@first, @last, @timezone)
      first = DateTime.to_unix(range.first)
      count = div(DateTime.diff(range.last, range.first), 60) + 1

      %{rows: rows} =
        Plausible.ClickhouseRepo.query!("""
        SELECT DISTINCT toUnixTimestamp(toStartOfHour(toTimeZone(
          toDateTime(#{first}, 'UTC') + number * 60, '#{@timezone}'))) AS bucket
        FROM numbers(#{count}) ORDER BY bucket
        """)

      query = %{dimensions: ["time:hour"], utc_time_range: range, timezone: @timezone}
      assert Time.time_keys(query) == Enum.map(rows, &hd/1)
    end
  end

  defp hourly_query(site, first, last) do
    QueryBuilder.build!(site,
      metrics: [:pageviews],
      dimensions: ["time:hour"],
      input_date_range: {:date_range, first, last},
      order_by: [{"time:hour", :asc}],
      include: [time_labels: true, time_label_result_indices: true]
    )
  end
end
