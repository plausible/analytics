defmodule PlausibleWeb.Plugins.API.Schemas.Goal do
  @moduledoc """
  OpenAPI schema for Goal
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Goal",
    description: "Goal object",
    type: :object,
    discriminator: %OpenApiSpex.Discriminator{
      propertyName: "goal_type",
      mapping: %{
        "Goal.CustomEvent" => Schemas.Goal.CustomEvent,
        "Goal.Pageview" => Schemas.Goal.Pageview,
        "Goal.Revenue" => Schemas.Goal.Revenue
      }
    },
    oneOf: [
      Schemas.Goal.CustomEvent,
      Schemas.Goal.Revenue,
      Schemas.Goal.Pageview
    ],
    example: %{
      goal_type: "Goal.Revenue",
      goal: %{
        currency: "EUR",
        event_name: "Purchase"
      }
    }
  })
end
