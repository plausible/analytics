defmodule Plausible.Ingestion.CountersTest do
  use Plausible.DataCase, async: true

  import Phoenix.ConnTest
  import Ecto.Query

  alias Plausible.Ingestion.Counters
  alias Plausible.Ingestion.Counters.Record
  alias Plausible.Ingestion.Event
  alias Plausible.Ingestion.Request

  describe "integration" do
    test "counters are written to the database based on event processing telemetry", %{test: test} do
      start_counters(
        ets_name: test,
        interval: 100,
        bucket_fn: fn ->
          DateTime.to_unix(DateTime.utc_now())
        end
      )

      {:ok, dropped} = emit_dropped_request()
      {:ok, buffered} = emit_buffered_request()

      verify_record_written(dropped.domain, "dropped_not_found")
      verify_record_written(buffered.domain, "buffered")
    end
  end

  describe "units" do
    test "counter buckets are minute-based spirals", %{test: test} do
      {:ok, {_, opts}} = Counters.init_cycle(ets_name: test, force_start?: true)
      assert opts[:bucket_fn] == (&Counters.minute_spiral/0)

      now1 = ~U[2023-02-14 18:26:18.243491Z]
      now2 = ~U[2023-02-14 18:26:58.143491Z]
      now3 = ~U[2023-02-14 18:27:39.273491Z]

      assert Counters.minute_spiral(now1) == Counters.minute_spiral(now2)
      assert Counters.minute_spiral(now3) - Counters.minute_spiral(now2) == 60
    end

    test "counter buckets are computed on aggregate", %{test: test} do
      self = self()

      {:ok, _} = Counters.init_cycle(force_start?: true, ets_name: test)

      Counters.handle_event(
        Event.telemetry_event_dropped(),
        nil,
        %{domain: "foo", reason: "bar"},
        bucket_fn: fn -> send(self, :bucket_computed) end,
        ets_name: test
      )

      assert_receive :computed
    end

    test "counter buckets are computed on dequeue", %{test: test} do
      self = self()

      {:ok, _} = Counters.init_cycle(force_start?: true, ets_name: test)

      Counters.handle_cycle(
        bucket_fn: fn -> send(self, :bucket_computed) end,
        ets_name: test
      )

      assert_receive :bucket_computed
    end
  end

  defp emit_dropped_request() do
    site = build(:site)

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)
    assert {:ok, %{dropped: [dropped]}} = Event.build_and_buffer(request)
    {:ok, dropped}
  end

  defp emit_buffered_request() do
    site = insert(:site)

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)
    assert {:ok, %{buffered: [buffered]}} = Event.build_and_buffer(request)
    {:ok, buffered}
  end

  defp start_counters(opts) do
    opts = Keyword.put(opts, :force_start?, true)
    %{start: {m, f, a}} = Counters.child_spec(opts)
    {:ok, _pid} = apply(m, f, a)
  end

  defp verify_record_written(domain, metric, value \\ 1) do
    query =
      from r in Record,
        where:
          r.domain == ^domain and
            r.metric == ^metric and
            r.value == ^value

    assert await_clickhouse_count(query, 1)
  end
end
