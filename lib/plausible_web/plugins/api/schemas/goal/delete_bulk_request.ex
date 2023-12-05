defmodule PlausibleWeb.Plugins.API.Schemas.Goal.DeleteBulkRequest do
  @moduledoc """
  OpenAPI schema for bulk Goal deletion request
  """
  use Plausible.Funnel.Const
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Goal.DeleteBulkRequest",
    description: "Goal deletion params",
    type: :object,
    required: [:goal_ids],
    properties: %{
      goal_ids: %Schema{
        type: :array,
        minItems: 1,
        maxItems: Funnel.Const.max_steps(),
        items: %Schema{type: :integer, description: "Goal ID"}
      }
    }
  })
end
