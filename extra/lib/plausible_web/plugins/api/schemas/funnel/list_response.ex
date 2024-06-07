defmodule PlausibleWeb.Plugins.API.Schemas.Funnel.ListResponse do
  @moduledoc """
  OpenAPI schema for Funnel list response
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Funnel.ListResponse",
    description: "Funnels list response",
    type: :object,
    required: [:funnels, :meta],
    properties: %{
      funnels: %Schema{
        items: Schemas.Funnel,
        type: :array
      },
      meta: %Schema{
        required: [:pagination],
        type: :object,
        properties: %{
          pagination: Schemas.PaginationMetadata
        }
      }
    }
  })
end
