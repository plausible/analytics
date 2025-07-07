defmodule Plausible.OpenTelemetry.Sampler do
  @moduledoc """
  [Custom OpenTelemetry sampler](https://hexdocs.pm/opentelemetry/readme.html#samplers)
  implementation that ignores particular traces to reduce noise. Ingestion
  HTTP requests and queries to Oban tables are ignored, for example.

  For non-ignored traces, implements trace ID ratio-based sampling following the method
  from [built-in sampler](https://github.com/open-telemetry/opentelemetry-erlang/blob/main/apps/opentelemetry/src/otel_sampler_trace_id_ratio_based.erl).
  """

  import Bitwise, only: [&&&: 2]

  # mask for extracting first 64 bits of trace ID
  # 2^63 - 1
  @max_value 9_223_372_036_854_775_807

  @behaviour :otel_sampler
  require OpenTelemetry.Tracer, as: Tracer

  @routes_to_ignore ["/api/event", "/api/event/", "/api//event", "//api/event"]
  @tables_to_ignore ["oban_jobs", "site_imports"]

  @impl true
  def setup(%{ratio: ratio}) when is_number(ratio) do
    %{ratio: ratio, id_upper_bound: ratio * @max_value}
  end

  @impl true
  def description(%{ratio: ratio}) do
    "#{inspect(__MODULE__)}{ratio=#{ratio}}"
  end

  @impl true
  def should_sample(context, trace_id, _links, _name, _kind, attributes, config) do
    tracestate = context |> Tracer.current_span_ctx() |> OpenTelemetry.Span.tracestate()

    case attributes do
      %{"db.instance": _db, source: source} when source in @tables_to_ignore ->
        {:drop, [], tracestate}

      %{"http.target": http_target} when http_target in @routes_to_ignore ->
        {:drop, [], tracestate}

      _any ->
        {decide(trace_id, config.id_upper_bound), [], tracestate}
    end
  end

  defp decide(trace_id, id_upper_bound) when is_integer(trace_id) and trace_id > 0 do
    lower_64_bits = trace_id &&& @max_value

    if abs(lower_64_bits) < id_upper_bound do
      :record_and_sample
    else
      :drop
    end
  end

  defp decide(_, _), do: :drop
end
