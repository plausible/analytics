defmodule Plausible.Ingestion.Counters.TelemetryHandlerTest do
  use Plausible.DataCase, async: true

  alias Plausible.Ingestion.Counters.Buffer
  alias Plausible.Ingestion.Counters.TelemetryHandler
  alias Plausible.Ingestion.Event

  test "install/1 attaches a telemetry handler", %{test: test} do
    on_exit(:detach, fn ->
      :telemetry.detach("ingest-counters-#{test}")
    end)

    buffer = Buffer.new(test)
    assert :ok = TelemetryHandler.install(buffer)

    all_handlers = :telemetry.list_handlers([:plausible, :ingest, :event])

    assert Enum.find(all_handlers, fn handler ->
             handler.config == buffer and
               handler.event_name == Event.telemetry_event_dropped()
           end)
  end

  test "handles ingest events by aggregating the counts", %{test: test} do
    on_exit(:detach, fn ->
      :telemetry.detach("ingest-counters-#{test}")
    end)

    buffer = Buffer.new(test)
    assert :ok = TelemetryHandler.install(buffer)

    e1 = %{
      domain: "a.example.com",
      request: %{timestamp: NaiveDateTime.utc_now(), tracker_script_version: 137}
    }

    e2 = %{
      domain: "b.example.com",
      request: %{timestamp: NaiveDateTime.utc_now(), tracker_script_version: 137}
    }

    :ok = Event.emit_telemetry_dropped(e1, :invalid)
    :ok = Event.emit_telemetry_dropped(e2, :not_found)
    :ok = Event.emit_telemetry_dropped(e2, :not_found)

    future = DateTime.utc_now() |> DateTime.add(120, :second)

    assert aggregates = Buffer.flush(buffer, future)

    assert Enum.find(aggregates, &match?({_, "dropped_invalid", "a.example.com", 137, 1}, &1))
    assert Enum.find(aggregates, &match?({_, "dropped_not_found", "b.example.com", 137, 2}, &1))
  end
end
