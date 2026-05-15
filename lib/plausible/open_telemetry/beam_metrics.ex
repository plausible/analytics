defmodule Plausible.OpenTelemetry.BeamMetrics do
  @moduledoc """
  Periodic BEAM process sampling via OpenTelemetry observable gauges.

  Uses `:recon.proc_count/2` to sample top-N processes by memory, reductions,
  and message queue length. Emits data as OTel observable gauge observations,
  exported via OTLP to the configured OTel Collector.

  Disabled by default. Enable with `BEAM_METRICS_ENABLED=true`.
  Collection interval controlled by `BEAM_METRICS_INTERVAL_MS` (default: 5000).
  """

  require Logger

  @top_n 20
  @metrics [:memory, :reductions, :message_queue_len]
  @process_info_keys [
    :registered_name,
    :current_function,
    :initial_call,
    :memory,
    :reductions,
    :message_queue_len
  ]

  @instruments %{
    memory:
      {:"beam.top_process.memory",
       %{description: "Memory usage of top BEAM processes", unit: :bytes}},
    reductions:
      {:"beam.top_process.reductions",
       %{description: "Reductions of top BEAM processes", unit: :"1"}},
    message_queue_len:
      {:"beam.top_process.message_queue_len",
       %{description: "Message queue length of top BEAM processes", unit: :"1"}}
  }

  @doc """
  Registers OTel observable gauge instruments and a shared callback.

  Should be called once during application startup when BEAM metrics are enabled.
  """
  def setup do
    scope = :opentelemetry.instrumentation_scope("plausible_beam_metrics", "0.1.0", :undefined)
    meter = :opentelemetry_experimental.get_meter(scope)

    gauges =
      Enum.map(@metrics, fn metric ->
        {name, opts} = Map.fetch!(@instruments, metric)
        :otel_meter.create_observable_gauge(meter, name, opts)
      end)

    :otel_meter.register_callback(meter, gauges, &observe_top_processes/1, [])

    Logger.info("BEAM metrics setup complete — sampling top #{@top_n} processes per metric")
    :ok
  end

  @doc """
  Callback invoked by the OTel Metric Reader on each collection cycle.

  Returns named observations for all three gauge instruments.
  """
  def observe_top_processes(_callback_args) do
    Enum.map(@metrics, fn metric ->
      {gauge_name, _opts} = Map.fetch!(@instruments, metric)
      observations = collect_observations(metric)
      {gauge_name, observations}
    end)
  end

  defp collect_observations(metric) do
    metric
    |> :recon.proc_count(@top_n)
    |> Enum.flat_map(fn {pid, value, _info} ->
      case Process.info(pid, @process_info_keys) do
        nil -> []
        info -> [{value, build_attributes(pid, info)}]
      end
    end)
  end

  defp build_attributes(pid, info) do
    registered_name =
      case Keyword.get(info, :registered_name) do
        [] -> ""
        name when is_atom(name) -> Atom.to_string(name)
        _ -> ""
      end

    current_function = format_mfa(Keyword.get(info, :current_function))
    initial_call = format_mfa(Keyword.get(info, :initial_call))

    %{
      "beam.process.pid" => inspect(pid),
      "beam.process.registered_name" => registered_name,
      "beam.process.current_function" => current_function,
      "beam.process.initial_call" => initial_call,
      "beam.process.memory" => to_string(Keyword.get(info, :memory, 0)),
      "beam.process.reductions" => to_string(Keyword.get(info, :reductions, 0)),
      "beam.process.message_queue_len" => to_string(Keyword.get(info, :message_queue_len, 0))
    }
  end

  defp format_mfa({m, f, a}), do: Exception.format_mfa(m, f, a)
  defp format_mfa(_), do: ""
end
