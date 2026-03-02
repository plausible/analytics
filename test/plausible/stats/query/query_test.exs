defmodule Plausible.Stats.QueryTest do
  use Plausible.DataCase
  alias Plausible.Stats
  alias Plausible.Stats.{ParsedQueryParams, QueryBuilder, QueryInclude}

  @user_id 123

  setup [:create_user, :create_site]

  describe "timeseries" do
    test "breakdown by time:minute (internal API), counts visitors and visits in all buckets their session was active in",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:10:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors, :visits, :pageviews],
          input_date_range: {:datetime_range, ~U[2021-01-01 00:00:00Z], ~U[2021-01-01 00:10:00Z]},
          dimensions: ["time:minute"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01 00:00:00"], metrics: [1, 1, 1]},
               %{dimensions: ["2021-01-01 00:01:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:02:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:03:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:04:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:05:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:06:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:07:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:08:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:09:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 00:10:00"], metrics: [1, 1, 1]}
             ]
    end

    test "breakdown by time:hour (internal API), counts visitors and visits in all buckets their session was active in",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:20:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:40:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 01:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 01:20:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors, :visits, :visit_duration],
          input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-01-02]},
          dimensions: ["time:hour"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01 00:00:00"], metrics: [1, 1, 0]},
               %{dimensions: ["2021-01-01 01:00:00"], metrics: [1, 1, 3600]}
             ]
    end

    test "shows month to date with time labels trimmed", %{site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-15 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-16 00:00:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors],
          input_date_range: :month,
          dimensions: ["time:day"],
          include: %QueryInclude{trim_relative_date_range: true},
          now: ~U[2021-01-15 12:00:00Z]
        })

      %Stats.QueryResult{results: results, query: query} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01"], metrics: [1]},
               %{dimensions: ["2021-01-15"], metrics: [1]}
             ]

      assert query[:date_range] == [
               "2021-01-01T00:00:00Z",
               "2021-01-15T23:59:59Z"
             ]
    end

    test "visitors and visits are smeared across time:minute buckets but visit_duration is not",
         %{site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 1, timestamp: ~N[2021-01-01 00:10:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-01 00:05:00]),
        build(:pageview, user_id: 2, timestamp: ~N[2021-01-01 00:08:00])
      ])

      {:ok, query} =
        QueryBuilder.build(site, %ParsedQueryParams{
          metrics: [:visitors, :visits, :visit_duration, :pageviews],
          input_date_range: {:datetime_range, ~U[2021-01-01 00:00:00Z], ~U[2021-01-01 00:30:00Z]},
          dimensions: ["time:minute"]
        })

      %Stats.QueryResult{results: results} = Stats.query(site, query)

      assert results == [
               %{dimensions: ["2021-01-01 00:00:00"], metrics: [1, 1, 0, 1]},
               %{dimensions: ["2021-01-01 00:01:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:02:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:03:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:04:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:05:00"], metrics: [2, 2, 0, 1]},
               %{dimensions: ["2021-01-01 00:06:00"], metrics: [2, 2, 0, 0]},
               %{dimensions: ["2021-01-01 00:07:00"], metrics: [2, 2, 0, 0]},
               %{dimensions: ["2021-01-01 00:08:00"], metrics: [2, 2, 180, 1]},
               %{dimensions: ["2021-01-01 00:09:00"], metrics: [1, 1, 0, 0]},
               %{dimensions: ["2021-01-01 00:10:00"], metrics: [1, 1, 600, 1]}
             ]
    end
  end

  describe "include.dashboard_metric_labels" do
    test "visitors -> Visitors (default)", %{site: site} do
      {:ok, query} =
        QueryBuilder.build(site,
          metrics: [:visitors],
          input_date_range: :all,
          include: [dashboard_metric_labels: true]
        )

      %Stats.QueryResult{meta: meta} = Stats.query(site, query)
      assert ["Visitors"] = meta[:metric_labels]
    end

    test "visitors -> Current visitors (realtime)", %{site: site} do
      {:ok, query} =
        QueryBuilder.build(site,
          metrics: [:visitors],
          input_date_range: :realtime,
          include: [dashboard_metric_labels: true]
        )

      %Stats.QueryResult{meta: meta} = Stats.query(site, query)
      assert ["Current visitors"] = meta[:metric_labels]
    end

    test "visitors -> Current visitors (realtime and goal filtered)", %{site: site} do
      insert(:goal, site: site, event_name: "Signup")

      {:ok, query} =
        QueryBuilder.build(site,
          metrics: [:visitors],
          input_date_range: :realtime,
          filters: [[:is, "event:goal", ["Signup"]]],
          include: [dashboard_metric_labels: true]
        )

      %Stats.QueryResult{meta: meta} = Stats.query(site, query)
      assert ["Current visitors"] = meta[:metric_labels]
    end

    test "visitors -> Conversions (goal filtered)", %{site: site} do
      insert(:goal, site: site, event_name: "Signup")

      {:ok, query} =
        QueryBuilder.build(site,
          metrics: [:visitors],
          input_date_range: :all,
          filters: [[:is, "event:goal", ["Signup"]]],
          include: [dashboard_metric_labels: true]
        )

      %Stats.QueryResult{meta: meta} = Stats.query(site, query)
      assert ["Conversions"] = meta[:metric_labels]
    end

    test "visitors -> Unique entrances (visit:entry_page dimension)", %{site: site} do
      {:ok, query} =
        QueryBuilder.build(site,
          metrics: [:visitors],
          input_date_range: :all,
          dimensions: ["visit:entry_page"],
          include: [dashboard_metric_labels: true]
        )

      %Stats.QueryResult{meta: meta} = Stats.query(site, query)
      assert ["Unique entrances"] = meta[:metric_labels]
    end

    test "visitors -> Unique exits (visit:exit_page dimension)", %{site: site} do
      {:ok, query} =
        QueryBuilder.build(site,
          metrics: [:visitors],
          input_date_range: :all,
          dimensions: ["visit:exit_page"],
          include: [dashboard_metric_labels: true]
        )

      %Stats.QueryResult{meta: meta} = Stats.query(site, query)
      assert ["Unique exits"] = meta[:metric_labels]
    end

    test "conversion_rate -> CR (default)", %{site: site} do
      {:ok, query} =
        QueryBuilder.build(site,
          metrics: [:conversion_rate],
          input_date_range: :all,
          dimensions: ["event:goal"],
          include: [dashboard_metric_labels: true]
        )

      %Stats.QueryResult{meta: meta} = Stats.query(site, query)
      assert ["CR"] = meta[:metric_labels]
    end

    test "maintains order with multiple metrics", %{site: site} do
      insert(:goal, site: site, event_name: "Signup")

      {:ok, query} =
        QueryBuilder.build(site,
          metrics: [:conversion_rate, :visitors],
          input_date_range: :all,
          filters: [[:is, "event:goal", ["Signup"]]],
          include: [dashboard_metric_labels: true]
        )

      %Stats.QueryResult{meta: meta} = Stats.query(site, query)
      assert ["CR", "Conversions"] = meta[:metric_labels]
    end
  end
end
