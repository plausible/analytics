defmodule PlausibleWeb.Plugins.API.Schemas.Goal.CreateRequest.CustomEvent do
  @moduledoc """
  OpenAPI schema for Custom Event Goal creation request
  """

  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Goal.CreateRequest.CustomEvent",
    description: "Custom Event Goal creation params",
    type: :object,
    required: [:goal, :goal_type],
    properties: %{
      goal_type: %Schema{
        type: :string,
        enum: ["Goal.CustomEvent"],
        default: "Goal.CustomEvent"
      },
      goal: %Schema{
        type: :object,
        required: [:event_name],
        properties: %{
          event_name: %Schema{type: :string},
          custom_props: %Schema{
            type: :object,
            description: "Custom properties (max 3, string keys and values)",
            additionalProperties: %Schema{type: :string},
            maxProperties: 3
          }
        }
      }
    },
    example: %{
      goal_type: "Goal.CustomEvent",
      goal: %{
        event_name: "Signup"
      }
    }
  })
end
