defmodule PlausibleWeb.Plugins.API.Schemas.PaginationMetadata do
  @moduledoc """
  Pagination metadata OpenAPI schema
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "PaginationMetadata",
    description: "Pagination meta data",
    type: :object,
    required: [:has_next_page, :has_prev_page],
    properties: %{
      has_next_page: %Schema{type: :boolean},
      has_prev_page: %Schema{type: :boolean},
      links: %Schema{
        properties: %{
          next: Schemas.Link,
          prev: Schemas.Link
        },
        type: :object
      }
    }
  })
end
