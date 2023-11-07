defmodule PlausibleWeb.Plugins.API.Schemas.Goal.ListResponse do
  @moduledoc """
  OpenAPI schema for Goals list response
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Goal.ListResponse",
    description: "Goals list response",
    type: :object,
    required: [:goals, :meta],
    properties: %{
      goals: %Schema{
        items: Schemas.Goal,
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
