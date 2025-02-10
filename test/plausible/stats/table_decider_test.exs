defmodule Plausible.Stats.TableDeciderTest do
  use Plausible.DataCase, async: true
  alias Plausible.Stats.Query

  import Plausible.Stats.TableDecider

  describe "events_join_sessions?" do
    test "with simple filters" do
      assert not events_join_sessions?(make_query([]))
      assert not events_join_sessions?(make_query(["event:name"]))
      assert not events_join_sessions?(make_query(["visit:source"]))
      assert events_join_sessions?(make_query(["visit:entry_page"]))
      assert events_join_sessions?(make_query(["visit:exit_page"]))
    end

    test "with nested filter" do
      assert not events_join_sessions?(
               make_query_full_filters([["not", ["is", "event:name", []]]])
             )

      assert events_join_sessions?(
               make_query_full_filters([["not", ["is", "visit:exit_page", []]]])
             )
    end
  end

  describe "partition_metrics" do
    test "with no metrics or filters" do
      query = make_query([])

      assert partition_metrics([], query) == {[], [], []}
    end

    test "session-only metrics accordingly" do
      query = make_query([])

      assert partition_metrics([:bounce_rate, :views_per_visit], query) ==
               {[], [:bounce_rate, :views_per_visit], []}
    end

    test "event-only metrics accordingly" do
      query = make_query([])

      assert partition_metrics([:total_revenue, :visitors], query) ==
               {[:total_revenue, :visitors], [], []}
    end

    test "filters from both, event-only metrics" do
      query = make_query(["event:name", "visit:source"])

      assert partition_metrics([:total_revenue], query) == {[:total_revenue], [], []}
    end

    test "filters from both, session-only metrics" do
      query = make_query(["event:name", "visit:source"])

      assert partition_metrics([:bounce_rate], query) == {[], [:bounce_rate], []}
    end

    test "session filters but no session metrics" do
      query = make_query(["visit:source"])

      assert partition_metrics([:total_revenue], query) == {[:total_revenue], [], []}
    end

    test "sample_percent is added to both types of metrics" do
      query = make_query([])

      assert partition_metrics([:total_revenue, :sample_percent], query) ==
               {[:total_revenue, :sample_percent], [], []}

      assert partition_metrics([:bounce_rate, :sample_percent], query) ==
               {[], [:bounce_rate, :sample_percent], []}

      assert partition_metrics([:total_revenue, :bounce_rate, :sample_percent], query) ==
               {[:total_revenue, :sample_percent], [:bounce_rate, :sample_percent], []}
    end

    test "other metrics put in its own result" do
      query = make_query([])

      assert partition_metrics([:time_on_page, :percentage], query) ==
               {[], [:percentage], [:time_on_page]}
    end

    test "metrics that can be calculated on either when event-only metrics" do
      query = make_query([])

      assert partition_metrics([:total_revenue, :visitors], query) ==
               {[:total_revenue, :visitors], [], []}

      assert partition_metrics([:pageviews, :visits], query) == {[:pageviews, :visits], [], []}
    end

    test "metrics that can be calculated on either when session-only metrics" do
      query = make_query([])

      assert partition_metrics([:bounce_rate, :visitors], query) ==
               {[], [:bounce_rate, :visitors], []}

      assert partition_metrics([:visit_duration, :visits], query) ==
               {[], [:visit_duration, :visits], []}
    end

    test "metrics that can be calculated on either are biased to events" do
      query = make_query([])

      assert partition_metrics([:bounce_rate, :total_revenue, :visitors], query) ==
               {[:total_revenue, :visitors], [:bounce_rate], []}
    end

    test "sample_percent is handled with either metrics" do
      query = make_query([])

      assert partition_metrics([:visitors, :sample_percent], query) ==
               {[], [:visitors, :sample_percent], []}
    end

    test "metric can be calculated on either, but filtering on events" do
      query = make_query(["event:name"])

      assert partition_metrics([:visitors], query) == {[:visitors], [], []}
    end

    test "metric can be calculated on either, but filtering on events and sessions" do
      query = make_query(["event:name", "visit:exit_page"])

      assert partition_metrics([:visitors], query) == {[], [:visitors], []}
    end

    test "metric can be calculated on either, filtering on either" do
      query = make_query(["visit:source"])

      assert partition_metrics([:visitors], query) == {[], [:visitors], []}
    end

    test "metric can be calculated on either, filtering on sessions" do
      query = make_query(["visit:exit_page"])

      assert partition_metrics([:visitors], query) == {[], [:visitors], []}
    end

    test "query dimensions lean metric" do
      assert partition_metrics([:visitors], make_query([], ["event:name"])) ==
               {[:visitors], [], []}

      assert partition_metrics([:visitors], make_query([], ["visit:source"])) ==
               {[], [:visitors], []}

      assert partition_metrics([:visitors], make_query([], ["visit:exit_page"])) ==
               {[], [:visitors], []}
    end
  end

  describe "validate_no_metrics_dimensions_conflict" do
    for {metrics, dimensions, expected} <- [
          {[], [], :ok},
          {[:bounce_rate], [], :ok},
          {[:scroll_depth], [], :ok},
          {[:bounce_rate], ["visit:exit_page"], :ok},
          {[:scroll_depth], ["event:name"], :ok},
          {[:scroll_depth], ["visit:device"], :ok},
          {[:bounce_rate, :scroll_depth], ["event:name"],
           {:error,
            "Session metric(s) `bounce_rate` cannot be queried along with event dimension(s) `event:name`"}},
          {[:visit_duration], ["event:props:foo"],
           {:error,
            "Session metric(s) `visit_duration` cannot be queried along with event dimension(s) `event:props:foo`"}},
          {[:bounce_rate, :scroll_depth], ["visit:exit_page"],
           {:error,
            "Event metric(s) `scroll_depth` cannot be queried along with session dimension(s) `visit:exit_page`"}},
          {[:bounce_rate, :scroll_depth], ["event:page"], :ok}
        ] do
      test "metrics #{inspect(metrics)} and dimensions #{inspect(dimensions)}" do
        query =
          make_query() |> Query.set(metrics: unquote(metrics), dimensions: unquote(dimensions))

        assert validate_no_metrics_dimensions_conflict(query) == unquote(expected)
      end
    end
  end

  defp make_query(filter_dimensions \\ [], dimensions \\ []) do
    Query.from(build(:site, id: :rand.uniform(100_000)), %{
      "filters" =>
        Enum.map(filter_dimensions, fn filter_dimension -> ["is", filter_dimension, []] end),
      "dimensions" => dimensions
    })
  end

  defp make_query_full_filters(filters) do
    Query.from(build(:site, id: :rand.uniform(100_000)), %{
      "dimensions" => [],
      "filters" => filters
    })
  end
end
