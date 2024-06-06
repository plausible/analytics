defmodule PlausibleWeb.Plugins.API.Schemas.Funnel do
  @moduledoc """
  OpenAPI schema for Funnel
  """
  use Plausible.Funnel.Const
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Funnel",
    description: "Funnel object",
    type: :object,
    properties: %{
      funnel: %Schema{
        type: :object,
        required: [:id, :name, :steps],
        properties: %{
          id: %Schema{type: :integer, description: "Funnel ID"},
          name: %Schema{type: :string, description: "Name"},
          steps: %Schema{
            description: "Funnel Steps",
            type: :array,
            minItems: 2,
            maxItems: Funnel.Const.max_steps(),
            items: Schemas.Goal
          }
        }
      }
    },
    example: %{
      funnel: %{
        id: 123,
        name: "My Marketing Funnel",
        steps: [
          %{
            goal_type: "Goal.Pageview",
            goal: %{
              id: 1,
              display_name: "Visit /product/1",
              path: "/product/1"
            }
          },
          %{
            goal_type: "Goal.Revenue",
            goal: %{
              id: 2,
              display_name: "Purchase",
              currency: "EUR",
              event_name: "Purchase"
            }
          }
        ]
      }
    }
  })
end
