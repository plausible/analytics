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

      assert partition_metrics([:time_on_page, :percentage, :total_visitors], query) ==
               {[], [:percentage], [:time_on_page, :total_visitors]}
    end

    test "metrics that can be calculated on either when event-only metrics" do
      query = make_query([])

      assert partition_metrics([:total_revenue, :visitors], query) ==
               {[:total_revenue, :visitors], [], []}

      assert partition_metrics([:total_revenue, :visits], query) ==
               {[:total_revenue, :visits], [], []}
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

    test "pageviews and events metrics are event-only when short time window" do
      query = make_query([], [], %{"period" => "day"})

      assert partition_metrics([:pageviews, :events, :bounce_rate], query) ==
               {[:pageviews, :events], [:bounce_rate], []}
    end

    test "pageviews and events metrics can be calculated via either table with longer time windows" do
      query = make_query([], [], %{"period" => "7d"})

      assert partition_metrics([:pageviews, :events, :bounce_rate], query) ==
               {[], [:bounce_rate, :pageviews, :events], []}
    end

    test "pageviews and events metrics are event-only when filters or dimensions" do
      query1 = make_query(["visit:exit_page"], [], %{"period" => "7d"})
      query2 = make_query([], ["visit:exit_page"], %{"period" => "7d"})

      assert partition_metrics([:pageviews, :events, :bounce_rate], query1) ==
               {[:pageviews, :events], [:bounce_rate], []}

      assert partition_metrics([:pageviews, :events, :bounce_rate], query2) ==
               {[:pageviews, :events], [:bounce_rate], []}
    end
  end

  defp make_query(filter_keys, dimensions \\ [], extra \\ %{}) do
    params =
      %{
        "filters" => Enum.map(filter_keys, fn filter_key -> ["is", filter_key, []] end),
        "dimensions" => dimensions
      }
      |> Map.merge(extra)

    Query.from(build(:site), params)
  end

  defp make_query_full_filters(filters) do
    Query.from(build(:site), %{
      "dimensions" => [],
      "filters" => filters
    })
  end
end
