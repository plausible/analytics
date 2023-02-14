defmodule Plausible.Ingestion.CountersTest do
  use Plausible.DataCase, async: true

  import Phoenix.ConnTest
  import Ecto.Query

  alias Plausible.Ingestion.Counters
  alias Plausible.Ingestion.Counters.Record
  alias Plausible.Ingestion.Event
  alias Plausible.Ingestion.Request

  describe "integration" do
    test "counters are written to the database", %{test: test} do
      start_counters(
        ets_name: test,
        interval: 100,
        bucket_fn: fn ->
          DateTime.to_unix(DateTime.utc_now())
        end
      )

      emit_dropped_request("test.example.com")

      query = from(r in Record, where: r.domain == "test.example.com")
      assert await_clickhouse_count(query, 1)
    end
  end

  defp emit_dropped_request(domain) do
    payload = %{
      name: "pageview",
      url: "http://#{domain}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)
    assert {:ok, %{buffered: [], dropped: [dropped]}} = Event.build_and_buffer(request)
    {:ok, dropped}
  end

  defp start_counters(opts) do
    opts = Keyword.put(opts, :force_start?, true)
    %{start: {m, f, a}} = Counters.child_spec(opts)
    {:ok, _pid} = apply(m, f, a)
  end
end
