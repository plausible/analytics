defmodule PlausibleWeb.Plugins.API.Schemas.SharedLink.ListResponse do
  @moduledoc """
  OpenAPI schema for SharedLink list response
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "SharedLink.ListResponse",
    description: "Shared Links list response",
    type: :object,
    required: [:shared_links, :meta],
    properties: %{
      shared_links: %Schema{
        items: Schemas.SharedLink,
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
