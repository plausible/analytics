defmodule PlausibleWeb.Plugins.API.Schemas.SharedLink.ListResponse do
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "SharedLink.ListResponse",
    description: "Shared Links list response",
    type: :object,
    required: [:data, :meta],
    properties: %{
      data: %Schema{
        items: Schemas.SharedLink,
        type: :array
      },
      meta: %OpenApiSpex.Schema{
        required: [:pagination],
        properties: %{
          pagination: %OpenApiSpex.Reference{
            "$ref": "#/components/schemas/PaginationMetadata"
          }
        },
        type: :object,
        items: Schemas.PaginationMetadata
      }
    }
  })
end
