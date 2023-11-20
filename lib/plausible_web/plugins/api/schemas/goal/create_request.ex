defmodule PlausibleWeb.Plugins.API.Schemas.Goal.CreateRequest do
  @moduledoc """
  OpenAPI schema for Goal creation request
  """
  use Plausible.Funnel.Const
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Goal.CreateRequest",
    description: "Goal creation params",
    type: :object,
    oneOf: [
      %Schema{
        title: "Goal.CreateRequest.BulkGetOrCreate",
        type: :object,
        description: "Bulk goal creation request",
        required: [:goals],
        properties: %{
          goals: %Schema{
            type: :array,
            minItems: 1,
            maxItems: Funnel.Const.max_steps(),
            items: %Schema{
              oneOf: [
                Schemas.Goal.CreateRequest.CustomEvent,
                Schemas.Goal.CreateRequest.Revenue,
                Schemas.Goal.CreateRequest.Pageview
              ]
            }
          }
        }
      },
      Schemas.Goal.CreateRequest.CustomEvent,
      Schemas.Goal.CreateRequest.Revenue,
      Schemas.Goal.CreateRequest.Pageview
    ]
  })
end
