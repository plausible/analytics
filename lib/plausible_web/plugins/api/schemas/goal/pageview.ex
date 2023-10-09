defmodule PlausibleWeb.Plugins.API.Schemas.Goal.Pageview do
  @moduledoc """
  OpenAPI schema for Pageview Goal object
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: "Pageview Goal object",
    title: "Goal.Pageview",
    type: :object,
    allOf: [
      Schemas.Goal.Type,
      %Schema{
        type: :object,
        required: [:goal],
        properties: %{
          goal: %Schema{
            type: :object,
            required: [:id, :display_name, :path],
            properties: %{
              id: %Schema{type: :integer, description: "Goal ID", readOnly: true},
              display_name: %Schema{type: :string, description: "Display name", readOnly: true},
              path: %Schema{type: :string, description: "Page Path"}
            }
          }
        }
      }
    ]
  })
end
