defmodule Plausible.OpenTelemetry.Sampler do
  @moduledoc """
  [Custom OpenTelemetry sampler](https://hexdocs.pm/opentelemetry/readme.html#samplers)
  implementation that ignores particular traces to reduce noise. Ingestion
  HTTP requests and queries to Oban tables are ignored, for example.

  For non-ignored traces, implements trace ID ratio-based sampling following the method
  from [built-in sampler](https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry/src/otel_sampler_trace_id_ratio_based.erl).
  """

  import Bitwise, only: [&&&: 2]

  # effective sampling ratio for non-ignored traces
  @ratio 0.5
  # 2^63 - 1
  @max_value 9_223_372_036_854_775_807

  @id_upper_bound @ratio * @max_value

  @behaviour :otel_sampler
  require OpenTelemetry.Tracer, as: Tracer

  @routes_to_ignore ["/api/event", "/api/event/"]
  @tables_to_ignore ["oban_jobs"]

  @impl true
  def setup(_sampler_opts), do: []

  @impl true
  def description(_sampler_config), do: inspect(__MODULE__)

  @impl true
  def should_sample(context, trace_id, _links, _name, _kind, attributes, _config) do
    tracestate = context |> Tracer.current_span_ctx() |> OpenTelemetry.Span.tracestate()

    case attributes do
      %{"db.instance": _db, source: source} when source in @tables_to_ignore ->
        {:drop, [], tracestate}

      %{"http.target": http_target} when http_target in @routes_to_ignore ->
        {:drop, [], tracestate}

      _any ->
        {decide(trace_id), [], tracestate}
    end
  end

  defp decide(trace_id) when is_integer(trace_id) and trace_id > 0 do
    lower_64_bits = trace_id &&& @max_value

    if abs(lower_64_bits) < @id_upper_bound do
      :record_and_sample
    else
      :drop
    end
  end

  defp decide(_), do: :drop
end
