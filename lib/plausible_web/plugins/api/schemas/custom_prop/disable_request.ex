defmodule PlausibleWeb.Plugins.API.Schemas.CustomProp.DisableRequest do
  @moduledoc """
  OpenAPI schema for Custom Property disable request
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "CustomProp.DisableRequest",
    description: "Custom Property disable params",
    type: :object,
    oneOf: [
      %Schema{
        title: "CustomProp.DisableRequest.BulkDisable",
        type: :object,
        description: "Bulk Custom Property disable request",
        required: [:custom_props],
        properties: %{
          custom_props: %Schema{
            type: :array,
            minItems: 1,
            items: Schemas.CustomProp
          }
        }
      },
      Schemas.CustomProp
    ],
    example: %{custom_props: [%{custom_prop: %{key: "author"}}]}
  })
end
