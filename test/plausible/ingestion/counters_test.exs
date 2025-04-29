defmodule Plausible.Ingestion.CountersTest do
  use Plausible.DataCase, async: false
  use Plausible.Teams.Test
  import Ecto.Query

  alias Plausible.Ingestion.Counters
  alias Plausible.Ingestion.Counters.Record
  alias Plausible.Ingestion.Event
  alias Plausible.Ingestion.Request

  import Phoenix.ConnTest

  @ts ~N[2023-02-14 01:00:03]

  describe "integration" do
    @tag :skip
    test "periodically flushes buffer aggregates to the database", %{test: test} do
      on_exit(:detach, fn ->
        :telemetry.detach("ingest-counters-#{test}")
      end)

      now = NaiveDateTime.utc_now()

      start_counters(
        buffer_name: test,
        interval: 100,
        aggregate_bucket_fn: fn _real_now ->
          now
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix()
        end,
        flush_boundary_fn: fn _real_now ->
          now
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.shift(second: 1)
          |> DateTime.to_unix()
        end
      )

      {:ok, dropped} = emit_dropped_request(at: now)
      {:ok, _dropped} = emit_dropped_request(domain: dropped.domain, at: now)
      {:ok, buffered} = emit_buffered_request(at: now)

      verify_record_written(dropped.domain, "dropped_not_found", 2)

      site_id = Plausible.Sites.get_by_domain(buffered.domain).id
      verify_record_written(buffered.domain, "buffered", 1, site_id)
    end

    @tag :skip
    test "the database eventually sums the records within 1-minute buckets", %{test: test} do
      # Testing if the database works is an unfunny way of integration testing,
      # but on the upside it's quite straight-forward way of testing if the
      # 1-minute bucket rollups are applied when dumping the records that are
      # originally aggregated with 10s windows.
      on_exit(:detach, fn ->
        :telemetry.detach("ingest-counters-#{test}")
      end)

      start_counters(
        buffer_name: test,
        interval: 100,
        aggregate_bucket_fn: fn _now ->
          ~N[2023-02-14 01:00:03]
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix()
        end,
        flush_boundary_fn: fn _now ->
          ~N[2023-02-14 01:00:56]
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix()
        end
      )

      event1_at = ~N[2023-02-14 01:00:03]
      event2_at = ~N[2023-02-14 01:00:18]
      event3_at = ~N[2023-02-14 01:00:55]

      {:ok, event1} = emit_dropped_request(at: event1_at)
      {:ok, _} = emit_dropped_request(domain: event1.domain, at: event2_at)
      {:ok, _} = emit_dropped_request(domain: event1.domain, at: event3_at)

      verify_record_written(event1.domain, "dropped_not_found", 3)
    end

    @tag :skip
    test "dumps the buffer on shutdown", %{test: test} do
      on_exit(:detach, fn ->
        :telemetry.detach("ingest-counters-#{test}")
      end)

      # normal operation, 10s cycle/10s bucket
      {:ok, pid} = start_counters(buffer_name: test)

      event1_at = ~N[2023-02-14 01:00:03]
      event2_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(10, :second)

      {:ok, event1} = emit_dropped_request(at: event1_at)
      {:ok, event2} = emit_dropped_request(at: event2_at)

      assert Process.alive?(pid)
      :ok = Counters.stop(pid)

      assert :down ==
               eventually(fn ->
                 {Process.alive?(pid) == false, :down}
               end)

      verify_record_written(event1.domain, "dropped_not_found", 1)
      verify_record_written(event2.domain, "dropped_not_found", 1)
    end
  end

  defp emit_dropped_request(opts) do
    domain = Keyword.get(opts, :domain, random_domain())
    at = Keyword.get(opts, :at, @ts)

    site = build(:site, domain: domain)

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}",
      v: 137
    }

    conn = build_conn(:post, "/api/event", payload)
    assert {:ok, request} = Request.build(conn, at)
    assert {:ok, %{dropped: [dropped]}} = Event.build_and_buffer(request)
    {:ok, dropped}
  end

  defp emit_buffered_request(opts) do
    domain = Keyword.get(opts, :domain, random_domain())
    at = Keyword.get(opts, :at, @ts)

    site = new_site(domain: domain)

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}",
      v: 137
    }

    conn = build_conn(:post, "/api/event", payload)
    assert {:ok, request} = Request.build(conn, at)
    assert {:ok, %{buffered: [buffered]}} = Event.build_and_buffer(request)

    {:ok, buffered}
  end

  defp start_counters(opts) do
    opts = Keyword.put(opts, :force_start?, true)
    %{start: {m, f, a}} = Counters.child_spec(opts)
    {:ok, _pid} = apply(m, f, a)
  end

  defp verify_record_written(domain, metric, value, site_id \\ nil) do
    query =
      from(r in Record,
        group_by: [:site_id, :domain, :metric, :event_timebucket, :tracker_script_version],
        where: r.domain == ^domain and r.metric == ^metric and r.tracker_script_version == 137,
        select: sum(r.value)
      )

    query =
      if site_id do
        query |> where([r], r.site_id == ^site_id)
      else
        query |> where([r], is_nil(r.site_id))
      end

    assert eventually(
             fn ->
               sums =
                 query
                 |> Plausible.ClickhouseRepo.all()

               {sums == [value], sums}
             end,
             100,
             10
           )
  end

  defp random_domain() do
    (:crypto.strong_rand_bytes(16) |> Base.encode16()) <> ".example.com"
  end
end
