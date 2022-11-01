defmodule Plausible.OpenTelemetry do
  @moduledoc false

  require OpenTelemetry.Tracer, as: Tracer

  def add_site_attributes(site) do
    case site do
      %Plausible.Site{} = site ->
        Tracer.set_attributes([
          {"plausible.site.id", site.id},
          {"plausible.site.domain", site.domain}
        ])

      id when is_integer(id) ->
        Tracer.set_attributes([{"plausible.site.id", id}])

      _any ->
        :ignore
    end
  end

  def add_user_attributes(user) do
    case user do
      %Plausible.Auth.User{} = user ->
        Tracer.set_attributes([
          {"plausible.user.id", user.id},
          {"plausible.user.name", user.name},
          {"plausible.user.email", user.email}
        ])

      id when is_integer(id) ->
        Tracer.set_attributes([{"plausible.user.id", id}])

      _any ->
        :ignore
    end
  end

  # https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/resource/semantic_conventions/README.md#service
  def resource_attributes(runtime_metadata) do
    [
      {"service.name", "analytics"},
      {"service.namespace", "plausible"},
      {"service.instance.id", runtime_metadata[:host]},
      {"service.version", runtime_metadata[:version]}
    ]
  end
end

defmodule Plausible.OpenTelemetry.Sampler do
  @moduledoc """
  [Custom OpenTelemetry sampler](https://hexdocs.pm/opentelemetry/readme.html#samplers)
  implementation that ignores `/api/event` traces, while recording 100% of other traces.
  """

  @behaviour :otel_sampler
  require OpenTelemetry.Tracer, as: Tracer

  @impl true
  def setup(_sampler_opts), do: []

  @impl true
  def description(_sampler_config), do: inspect(__MODULE__)

  @impl true
  def should_sample(context, _trace_id, _links, _name, _kind, attributes, _config)
      when attributes."http.target" == "/api/event" do
    tracestate = context |> Tracer.current_span_ctx() |> OpenTelemetry.Span.tracestate()
    {:drop, [], tracestate}
  end

  @impl true
  def should_sample(context, _trace_id, _links, _name, _kind, _attributes, _config) do
    tracestate = context |> Tracer.current_span_ctx() |> OpenTelemetry.Span.tracestate()
    {:record_and_sample, [], tracestate}
  end
end
