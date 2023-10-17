defmodule PlausibleWeb.Plugins.API.Schemas.Goal.CustomEvent do
  @moduledoc """
  OpenAPI schema for Custom Event Goal object
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: "Custom Event Goal object",
    title: "Goal.CustomEvent",
    type: :object,
    allOf: [
      Schemas.Goal.Type,
      %Schema{
        type: :object,
        required: [:goal],
        properties: %{
          goal: %Schema{
            type: :object,
            required: [:id, :display_name, :event_name],
            properties: %{
              id: %Schema{type: :integer, description: "Goal ID", readOnly: true},
              display_name: %Schema{type: :string, description: "Display name", readOnly: true},
              event_name: %Schema{type: :string, description: "Event Name"}
            }
          }
        }
      }
    ]
  })
end
