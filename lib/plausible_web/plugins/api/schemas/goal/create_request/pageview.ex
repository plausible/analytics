defmodule PlausibleWeb.Plugins.API.Schemas.Goal.CreateRequest.Pageview do
  @moduledoc """
  OpenAPI schema for Pageview Goal creation request
  """

  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Goal.CreateRequest.Pageview",
    description: "Pageview Goal creation params",
    type: :object,
    required: [:goal, :goal_type],
    properties: %{
      goal_type: %Schema{
        type: :string,
        enum: ["Goal.Pageview"],
        default: "Goal.Pageview"
      },
      goal: %Schema{
        type: :object,
        required: [:path],
        properties: %{
          path: %Schema{type: :string}
        }
      }
    },
    example: %{
      goal_type: "Goal.Pageview",
      goal: %{
        path: "/checkout"
      }
    }
  })
end
