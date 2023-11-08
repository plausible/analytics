defmodule PlausibleWeb.Plugins.API.Schemas.Error do
  @moduledoc """
  OpenAPI schema for an error included in a response
  """

  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: """
    An explanation of an error that occurred within the Plugins API
    """,
    type: :object,
    required: [:detail],
    properties: %{detail: %Schema{type: :string}}
  })
end
