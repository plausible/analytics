defmodule PlausibleWeb.Plugins.API.Schemas.PaymentRequired do
  @moduledoc """
  OpenAPI schema for a generic 402 response
  """

  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: """
    The response that is returned when the user makes a request that cannot be
    processed due to their subscription limitations.
    """,
    type: :object,
    title: "PaymentRequiredError",
    required: [:errors],
    properties: %{
      errors: %Schema{
        items: Schemas.Error,
        type: :array
      }
    }
  })
end
