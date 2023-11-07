defmodule PlausibleWeb.Plugins.API.Schemas.NotFound do
  @moduledoc """
  OpenAPI schema for a generic 404 response
  """

  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: """
    The response that is returned when the user makes a request to a non-existing resource
    """,
    type: :object,
    title: "NotFoundError",
    required: [:errors],
    properties: %{
      errors: %Schema{
        items: Schemas.Error,
        type: :array
      }
    }
  })
end
