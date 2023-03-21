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
  implementation that ignores particular traces to reduce noise. Ingestion
  HTTP requests and queries to Oban tables are ignored, for example.
  """

  @behaviour :otel_sampler
  require OpenTelemetry.Tracer, as: Tracer

  @routes_to_ignore ["/api/event", "/api/event/"]
  @tables_to_ignore ["oban_jobs"]

  @impl true
  def setup(_sampler_opts), do: []

  @impl true
  def description(_sampler_config), do: inspect(__MODULE__)

  @impl true
  def should_sample(context, _trace_id, _links, _name, _kind, attributes, _config) do
    tracestate = context |> Tracer.current_span_ctx() |> OpenTelemetry.Span.tracestate()

    case attributes do
      %{"db.instance": _db, source: source} when source in @tables_to_ignore ->
        {:drop, [], tracestate}

      %{"http.target": http_target} when http_target in @routes_to_ignore ->
        {:drop, [], tracestate}

      _any ->
        {:record_and_sample, [], tracestate}
    end
  end
end
