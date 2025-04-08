defmodule PlausibleWeb.Plugins.API.Schemas.Capabilities do
  @moduledoc """
  OpenAPI schema for Capabilities
  """
  use PlausibleWeb, :open_api_schema
  require Plausible.Billing.Feature

  @features Plausible.Billing.Feature.list_short_names()
  @features_schema Enum.reduce(@features, %{}, fn feature, acc ->
                     Map.put(acc, feature, %Schema{type: :boolean})
                   end)

  OpenApiSpex.schema(%{
    title: "Capabilities",
    description: "Capabilities object",
    type: :object,
    required: [:authorized, :data_domain, :features],
    properties: %{
      authorized: %Schema{type: :boolean},
      data_domain: %Schema{type: :string, nullable: true},
      features: %Schema{
        type: :object,
        required: @features,
        properties: @features_schema
      }
    },
    example: %{
      authorized: true,
      data_domain: "example.com",
      features: %{
        Funnels: false,
        Goals: true,
        Props: false,
        RevenueGoals: false,
        StatsAPI: false,
        SiteSegments: false
      }
    }
  })
end
