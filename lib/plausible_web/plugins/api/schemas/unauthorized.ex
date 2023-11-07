defmodule PlausibleWeb.Plugins.API.Schemas.Unauthorized do
  @moduledoc """
  OpenAPI schema for a generic 401 response
  """

  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: """
    The response that is returned when the user makes an unauthorized request.
    """,
    type: :object,
    title: "UnauthorizedError",
    required: [:errors],
    properties: %{
      errors: %Schema{
        items: Schemas.Error,
        type: :array
      }
    }
  })
end
