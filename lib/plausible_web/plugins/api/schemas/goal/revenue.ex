defmodule PlausibleWeb.Plugins.API.Schemas.Goal.Revenue do
  @moduledoc """
  OpenAPI schema for Revenue Goal object
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: "Revenue Goal object",
    title: "Goal.Revenue",
    type: :object,
    allOf: [
      Schemas.Goal.Type,
      %Schema{
        type: :object,
        required: [:goal],
        properties: %{
          goal: %Schema{
            type: :object,
            required: [:id, :display_name, :event_name, :currency],
            properties: %{
              id: %Schema{type: :integer, description: "Goal ID", readOnly: true},
              display_name: %Schema{type: :string, description: "Display name", readOnly: true},
              event_name: %Schema{type: :string, description: "Event Name"},
              currency: %Schema{type: :string, description: "Currency"}
            }
          }
        }
      }
    ]
  })
end
