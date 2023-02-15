defmodule Plausible.Ingestion.Counters.TelemetryHandler do
  @moduledoc """
  Susbcribes to telemetry events emitted by `Plausible.Ingestion.Event`.
  Every time a user-event is either dispatched to clickhouse or dropped,
  a telemetry event is emitted respecitvely. That event is captured here,
  its metadata is extracted and sent for internal stats aggregation via
  `Counters.Buffer` interface. 
  """
  alias Plausible.Ingestion.Counters
  alias Plausible.Ingestion.Event

  @event_dropped Event.telemetry_event_dropped()
  @event_buffered Event.telemetry_event_buffered()

  @telemetry_events [@event_dropped, @event_buffered]
  @telemetry_handler &__MODULE__.handle_event/4

  @spec install(Counters.Buffer.t()) :: :ok
  def install(%Counters.Buffer{buffer_name: buffer_name} = buffer) do
    :ok =
      :telemetry.attach_many(
        "ingest-counters-#{buffer_name}",
        @telemetry_events,
        @telemetry_handler,
        buffer
      )
  end

  @spec handle_event([atom()], any(), map(), Counters.Buffer.t()) :: :ok
  def handle_event(@event_dropped, _measurements, %{domain: domain, reason: reason}, buffer) do
    Counters.Buffer.aggregate(buffer, "dropped_#{reason}", domain)
  end

  def handle_event(@event_buffered, _measurements, %{domain: domain}, buffer) do
    Counters.Buffer.aggregate(buffer, "buffered", domain)
  end
end
