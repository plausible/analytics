defmodule Plausible.OpenTelemetry do
  @moduledoc false

  alias OpenTelemetry.Tracer

  @doc """
  Current trace ID as a 32-character lowercase hex string, or nil outside a span.

  Reads the SDK's precomputed fixed-width field.
  """
  def current_trace_id do
    case Tracer.current_span_ctx() do
      :undefined ->
        nil

      span_ctx ->
        OpenTelemetry.Span.hex_trace_id(span_ctx)
    end
  end

  def add_site_attributes(site) do
    case site do
      %Plausible.Site{} = site ->
        Tracer.set_attributes([
          {"plausible.site.id", site.id},
          {"plausible.site.domain", site.domain},
          {"plausible.site.team_id", site.team_id}
        ])

      id when is_integer(id) ->
        Tracer.set_attributes([{"plausible.site.id", id}])

      _any ->
        :ignore
    end
  end

  def add_site_attributes(site, credential) do
    add_site_attributes(site)

    if is_nil(credential.team_id), do: Tracer.set_attribute("plausible.team.id", site.team_id)
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

  def add_credential_attributes(credential) do
    Tracer.set_attributes([
      {"plausible.user.id", credential.user_id},
      {"plausible.credential.type", credential_type(credential)},
      {"plausible.credential.id", credential.id}
    ])

    if credential.team_id, do: Tracer.set_attribute("plausible.team.id", credential.team_id)
  end

  defp credential_type(%Plausible.Auth.ApiKey{}), do: "api_key"

  # https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/resource/semantic_conventions/README.md#service
  def resource_attributes(runtime_metadata) do
    [
      {"service.name", "analytics"},
      {"service.namespace", "plausible"},
      {"service.version", runtime_metadata[:version]}
    ]
  end
end
