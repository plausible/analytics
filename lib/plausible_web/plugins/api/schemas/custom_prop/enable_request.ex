defmodule PlausibleWeb.Plugins.API.Schemas.CustomProp.EnableRequest do
  @moduledoc """
  OpenAPI schema for Custom Property creation request
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "CustomProp.EnableRequest",
    description: "Custom Property enable params",
    type: :object,
    oneOf: [
      %Schema{
        title: "CustomProp.EnableRequest.BulkEnable",
        type: :object,
        description: "Bulk Custom Property enable request",
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
