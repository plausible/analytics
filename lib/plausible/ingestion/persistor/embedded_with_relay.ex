defmodule Plausible.Ingestion.Persistor.EmbeddedWithRelay do
  @moduledoc """
  Embedded implementation with async relay to remote.
  """

  alias Plausible.Ingestion.Persistor

  def persist_event(event, previous_user_id, opts) do
    Task.start(fn ->
      Plausible.PromEx.Plugins.PlausibleMetrics.measure_duration(
        telemetry_pipeline_step_duration(),
        fn -> do_persist_event(event, previous_user_id, opts) end,
        %{step: "register_session"}
      )
    end)

    Persistor.Embedded.persist_event(event, previous_user_id, opts)
  end

  defp do_persist_event(event, previous_user_id, opts) do
    result = Persistor.Remote.persist_event(event, previous_user_id, opts)

    case result do
      {:ok, event} ->
        emit_telemetry_buffered(event)

      {:error, reason} ->
        emit_telemetry_dropped(event, reason)
    end
  end

  def emit_telemetry_buffered(event) do
    :telemetry.execute(telemetry_event_buffered(), %{}, %{
      domain: event.domain,
      request_timestamp: event.request.timestamp,
      tracker_script_version: event.request.tracker_script_version
    })
  end

  def emit_telemetry_dropped(event, reason) do
    :telemetry.execute(
      telemetry_event_dropped(),
      %{},
      %{
        domain: event.domain,
        reason: reason,
        request_timestamp: event.request.timestamp,
        tracker_script_version: event.request.tracker_script_version
      }
    )
  end

  def telemetry_event_buffered() do
    [:plausible, :remote_ingest, :event, :buffered]
  end

  def telemetry_event_dropped() do
    [:plausible, :remote_ingest, :event, :dropped]
  end

  def telemetry_pipeline_step_duration() do
    [:plausible, :remote_ingest, :pipeline, :step]
  end
end
