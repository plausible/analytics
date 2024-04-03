defmodule Plausible.Stats.TableDeciderTest do
  use Plausible.DataCase, async: true
  alias Plausible.Stats.Query

  import Plausible.Stats.TableDecider

  test "events_join_sessions? with experimental_reduced_joins disabled" do
    assert not events_join_sessions?(make_query(false, %{}))
    assert not events_join_sessions?(make_query(false, %{name: "pageview"}))
    assert events_join_sessions?(make_query(false, %{source: "Google"}))
    assert events_join_sessions?(make_query(false, %{entry_page: "/"}))
    assert events_join_sessions?(make_query(false, %{exit_page: "/"}))
  end

  test "events_join_sessions? with experimental_reduced_joins enabled" do
    assert not events_join_sessions?(make_query(true, %{}))
    assert not events_join_sessions?(make_query(true, %{name: "pageview"}))
    assert not events_join_sessions?(make_query(true, %{source: "Google"}))
    assert events_join_sessions?(make_query(true, %{entry_page: "/"}))
    assert events_join_sessions?(make_query(true, %{exit_page: "/"}))
  end

  describe "partition_metrics" do
    test "with no metrics or filters" do
      query = make_query(false, %{})

      assert partition_metrics([], query) == {[], [], []}
    end

    test "events-only metrics accordingly" do
      query = make_query(false, %{})

      assert partition_metrics([:bounce_rate, :views_per_visit], query) ==
               {[], [:bounce_rate, :views_per_visit], []}
    end

    test "session-only metrics accordingly" do
      query = make_query(false, %{})

      assert partition_metrics([:total_revenue, :visitors], query) ==
               {[:total_revenue, :visitors], [], []}
    end

    test "filters from both, event-only metrics" do
      query = make_query(false, %{name: "pageview", source: "Google"})

      assert partition_metrics([:total_revenue], query) == {[:total_revenue], [], []}
    end

    test "filters from both, session-only metrics" do
      query = make_query(false, %{name: "pageview", source: "Google"})

      assert partition_metrics([:bounce_rate], query) == {[], [:bounce_rate], []}
    end

    test "session filters but no session metrics" do
      query = make_query(false, %{source: "Google"})

      assert partition_metrics([:total_revenue], query) == {[:total_revenue], [], []}
    end

    test "sample_percent is added to both types of metrics" do
      query = make_query(false, %{})

      assert partition_metrics([:total_revenue, :sample_percent], query) ==
               {[:total_revenue, :sample_percent], [], []}

      assert partition_metrics([:bounce_rate, :sample_percent], query) ==
               {[], [:bounce_rate, :sample_percent], []}

      assert partition_metrics([:total_revenue, :bounce_rate, :sample_percent], query) ==
               {[:total_revenue, :sample_percent], [:bounce_rate, :sample_percent], []}
    end

    test "other metrics put in its own result" do
      query = make_query(false, %{})

      assert partition_metrics([:time_on_page, :percentage, :total_visitors], query) ==
               {[], [], [:time_on_page, :percentage, :total_visitors]}
    end

    test "raises if unknown metric" do
      query = make_query(false, %{})

      assert_raise ArgumentError, fn ->
        partition_metrics([:foobar], query)
      end
    end
  end

  describe "partition_metrics with experimental_reduced_joins enabled" do
    test "metrics that can be calculated on either when event-only metrics" do
      query = make_query(true, %{})

      assert partition_metrics([:total_revenue, :visitors], query) ==
               {[:total_revenue, :visitors], [], []}

      assert partition_metrics([:pageviews, :visits], query) == {[:pageviews, :visits], [], []}
    end

    test "metrics that can be calculated on either when session-only metrics" do
      query = make_query(true, %{})

      assert partition_metrics([:bounce_rate, :visitors], query) ==
               {[], [:bounce_rate, :visitors], []}

      assert partition_metrics([:visit_duration, :visits], query) ==
               {[], [:visit_duration, :visits], []}
    end

    test "metrics that can be calculated on either are biased to sessions" do
      query = make_query(true, %{})

      assert partition_metrics([:bounce_rate, :total_revenue, :visitors], query) ==
               {[:total_revenue], [:bounce_rate, :visitors], []}
    end

    test "sample_percent is handled with either metrics" do
      query = make_query(true, %{})

      assert partition_metrics([:visitors, :sample_percent], query) ==
               {[], [:visitors, :sample_percent], []}
    end

    test "metric can be calculated on either, but filtering on events" do
      query = make_query(true, %{name: "pageview"})

      assert partition_metrics([:visitors], query) == {[:visitors], [], []}
    end

    test "metric can be calculated on either, but filtering on events and sessions" do
      query = make_query(true, %{name: "pageview", exit_page: "/"})

      assert partition_metrics([:visitors], query) == {[], [:visitors], []}
    end

    test "metric can be calculated on either, filtering on either" do
      query = make_query(true, %{source: "Google"})

      assert partition_metrics([:visitors], query) == {[], [:visitors], []}
    end

    test "metric can be calculated on either, filtering on sessions" do
      query = make_query(true, %{exit_page: "/"})

      assert partition_metrics([:visitors], query) == {[], [:visitors], []}
    end

    test "breakdown value leans metric" do
      query = make_query(true, %{})

      assert partition_metrics([:visitors], query, "event:name") == {[:visitors], [], []}
      assert partition_metrics([:visitors], query, "visit:source") == {[], [:visitors], []}
      assert partition_metrics([:visitors], query, "visit:exit_page") == {[], [:visitors], []}
    end
  end

  defp make_query(experimental_reduced_joins?, filters) do
    Query.from(build(:site), %{
      "experimental_reduced_joins" => to_string(experimental_reduced_joins?),
      "filters" => Jason.encode!(filters)
    })
  end
end
