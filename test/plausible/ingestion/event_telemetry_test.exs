defmodule Plausible.Ingestion.EventTelemetryTest do
  import Phoenix.ConnTest
  import Plausible.Teams.Test

  alias Plausible.Ingestion.Request
  alias Plausible.Ingestion.Event

  use Plausible.DataCase, async: false

  @tag :skip
  test "telemetry is emitted for all events", %{test: test} do
    test_pid = self()

    telemetry_dropped = Event.telemetry_event_dropped()
    telemetry_buffered = Event.telemetry_event_buffered()

    :telemetry.attach_many(
      "#{test}-telemetry-handler",
      [
        telemetry_dropped,
        telemetry_buffered
      ],
      fn event, %{}, metadata, _ ->
        send(test_pid, {:telemetry_handled, event, metadata})
      end,
      %{}
    )

    site = new_site(ingest_rate_limit_threshold: 2)

    payload = %{
      name: "pageview",
      url: "http://dummy.site",
      d: "#{site.domain}"
    }

    conn = build_conn(:post, "/api/events", payload)
    assert {:ok, request} = Request.build(conn)

    for _ <- 1..3, do: Event.build_and_buffer(request)

    assert_receive {:telemetry_handled, ^telemetry_buffered, %{}}
    assert_receive {:telemetry_handled, ^telemetry_buffered, %{}}
    assert_receive {:telemetry_handled, ^telemetry_dropped, %{reason: :throttle}}
  end
end
