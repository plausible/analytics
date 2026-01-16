defmodule Plausible.OpenTelemetry.Logger do
  @moduledoc """
  Telemetry handler that adds the OpenTelemetry trace_id to Logger metadata.

  This enables correlation between log lines and distributed traces.
  The trace_id is extracted from the current OTel span context and added
  to the Logger metadata when Phoenix router dispatch starts.
  """

  require Logger

  @doc """
  Attaches telemetry handlers to set trace_id in Logger metadata.

  Should be called during application startup, after OpentelemetryPhoenix.setup().
  """
  def setup do
    :telemetry.attach(
      "plausible-otel-logger-metadata",
      [:phoenix, :router_dispatch, :start],
      &__MODULE__.handle_router_dispatch_start/4,
      %{}
    )
  end

  @doc false
  def handle_router_dispatch_start(_event, _measurements, _metadata, _config) do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        :ok

      span_ctx ->
        trace_id = OpenTelemetry.Span.trace_id(span_ctx)
        trace_id_hex = Integer.to_string(trace_id, 16) |> String.downcase()
        Logger.metadata(trace_id: trace_id_hex)
    end
  end
end
