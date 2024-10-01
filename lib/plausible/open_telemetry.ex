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
      {"service.instance.app_host", runtime_metadata[:app_host]},
      {"service.instance.id", runtime_metadata[:host]},
      {"service.version", runtime_metadata[:version]}
    ]
  end
end
