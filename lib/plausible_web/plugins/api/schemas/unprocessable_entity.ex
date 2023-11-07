defmodule PlausibleWeb.Plugins.API.Schemas.UnprocessableEntity do
  @moduledoc """
  OpenAPI schema for a generic 422 response
  """

  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: """
    The response that is returned when the user makes a request that cannot be
    processed.
    """,
    type: :object,
    title: "UnprocessableEntityError",
    required: [:errors],
    properties: %{
      errors: %Schema{
        items: Schemas.Error,
        type: :array
      }
    }
  })
end
