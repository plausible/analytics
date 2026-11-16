defmodule ObanErrorReporter do
  @moduledoc """
  Handler module for processing Oban errors. 
  """

  use Plausible
  require Logger

  def handle_event(name, measurements, metadata, _) do
    # handling telemetry event in a try/catch block
    # to avoid handler detachment in the case of an error
    # see https://hexdocs.pm/telemetry/telemetry.html#attach/4
    try do
      handle_event(name, measurements, metadata)
    catch
      kind, reason ->
        message = Exception.format(kind, reason, __STACKTRACE__)
        Logger.error(message)
    end
  end

  defp handle_event([:oban, :job, :exception], measure, %{job: job} = meta) do
    extra =
      job
      |> Map.take([:id, :args, :meta, :queue, :worker])
      |> Map.merge(measure)

    capture_error(meta, extra)
  end

  defp handle_event([:oban, :notifier, :exception], _timing, meta) do
    extra = Map.take(meta, ~w(channel payload)a)
    capture_error(meta, extra)
  end

  defp handle_event([:oban, :plugin, :exception], _timing, meta) do
    extra = Map.take(meta, ~w(plugin)a)
    capture_error(meta, extra)
  end

  # Logs the error and sends it to Sentry
  defp capture_error(meta, extra) do
    Logger.error(
      # this message is ignored by Sentry
      "Background job (#{inspect(extra)}) failed:\n\n  " <>
        Exception.format(:error, meta.reason, meta.stacktrace),
      # Sentry report is built entirely from crash_reason
      crash_reason: {meta.reason, meta.stacktrace},
      sentry: %{extra: extra}
    )
  end
end
