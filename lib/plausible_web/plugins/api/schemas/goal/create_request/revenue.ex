defmodule PlausibleWeb.Plugins.API.Schemas.Goal.CreateRequest.Revenue do
  @moduledoc """
  OpenAPI schema for Custom Event Goal creation request
  """

  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Goal.CreateRequest.Revenue",
    description: "Revenue Goal creation params",
    type: :object,
    required: [:goal, :goal_type],
    properties: %{
      goal_type: %Schema{
        type: :string,
        enum: ["Goal.Revenue"],
        default: "Goal.Revenue"
      },
      goal: %Schema{
        type: :object,
        required: [:event_name, :currency],
        properties: %{
          event_name: %Schema{type: :string},
          currency: %Schema{type: :string}
        }
      }
    },
    example: %{
      goal_type: "Goal.Revenue",
      goal: %{
        event_name: "Purchase",
        currency: "EUR"
      }
    }
  })
end
