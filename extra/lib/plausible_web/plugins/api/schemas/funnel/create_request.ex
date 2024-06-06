defmodule PlausibleWeb.Plugins.API.Schemas.Funnel.CreateRequest do
  @moduledoc """
  OpenAPI schema for Funnel creation request - get or creates goals along the way
  """
  use Plausible.Funnel.Const
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Funnel.CreateRequest",
    description: "Funnel creation params",
    type: :object,
    required: [:funnel],
    properties: %{
      funnel: %Schema{
        type: :object,
        required: [:steps, :name],
        properties: %{
          steps: %Schema{
            description: "Funnel Steps",
            type: :array,
            minItems: 2,
            maxItems: Funnel.Const.max_steps(),
            items: %Schema{
              oneOf: [
                Schemas.Goal.CreateRequest.CustomEvent,
                Schemas.Goal.CreateRequest.Revenue,
                Schemas.Goal.CreateRequest.Pageview
              ]
            }
          },
          name: %Schema{type: :string, description: "Funnel Name"}
        }
      }
    },
    example: %{
      funnel: %{
        name: "My First Funnel",
        steps: [
          %{
            goal_type: "Goal.Pageview",
            goal: %{
              path: "/product/123"
            }
          },
          %{
            goal_type: "Goal.Revenue",
            goal: %{
              currency: "EUR",
              event_name: "Purchase"
            }
          }
        ]
      }
    }
  })
end
