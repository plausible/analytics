defmodule Plausible.Ingestion.CountersTest do
  use Plausible.DataCase, async: false
  import Ecto.Query

  alias Plausible.Ingestion.Counters
  alias Plausible.Ingestion.Counters.Record
  alias Plausible.Ingestion.Event
  alias Plausible.Ingestion.Request

  import Phoenix.ConnTest

  describe "integration" do
    test "periodically flushes buffer aggregates to the database", %{test: test} do
      on_exit(:detach, fn ->
        :telemetry.detach("ingest-counters-#{test}")
      end)

      start_counters(
        buffer_name: test,
        interval: 100,
        flush_boundary_fn: fn _now ->
          System.os_time(:second)
        end
      )

      {:ok, dropped} = emit_dropped_request()
      {:ok, buffered} = emit_buffered_request()

      verify_record_written(dropped.domain, "dropped_not_found", 1)

      site_id = Plausible.Sites.get_by_domain(buffered.domain).id
      verify_record_written(buffered.domain, "buffered", 1, site_id)
    end
  end

  defp emit_dropped_request() do
    site = build(:site, domain: random_domain())

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}"
    }

    conn = build_conn(:post, "/api/event", payload)
    assert {:ok, request} = Request.build(conn)
    assert {:ok, %{dropped: [dropped]}} = Event.build_and_buffer(request)
    {:ok, dropped}
  end

  defp emit_buffered_request() do
    site = insert(:site, domain: random_domain())

    payload = %{
      name: "pageview",
      url: "http://#{site.domain}"
    }

    conn = build_conn(:post, "/api/event", payload)
    assert {:ok, request} = Request.build(conn)
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
        where:
          r.domain == ^domain and
            r.metric == ^metric and
            r.value == ^value
      )

    query =
      if site_id do
        query |> where([r], r.site_id == ^site_id)
      else
        query |> where([r], is_nil(r.site_id))
      end

    assert await_clickhouse_count(query, 1)
  end

  defp random_domain() do
    (:crypto.strong_rand_bytes(16) |> Base.encode16()) <> ".example.com"
  end
end
