defmodule PlausibleWeb.Plugins.API.Schemas.Goal.Type do
  @moduledoc """
  OpenAPI schema for common Goal Type

  Future-proof: funnels etc.
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Goal.Type",
    description: "Properties common to all Goals",
    type: :object,
    properties: %{
      goal_type: %Schema{type: :string}
    },
    required: [:goal_type]
  })
end
