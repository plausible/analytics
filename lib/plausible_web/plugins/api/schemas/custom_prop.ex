defmodule PlausibleWeb.Plugins.API.Schemas.CustomProp do
  @moduledoc """
  OpenAPI schema for Goal
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "CustomProp",
    description: "Custom Property object",
    type: :object,
    required: [:custom_prop],
    properties: %{
      custom_prop: %Schema{
        type: :object,
        required: [:key],
        properties: %{
          key: %Schema{type: :string, description: "Custom Property Key"}
        }
      }
    },
    example: %{
      custom_prop: %{
        key: "author"
      }
    }
  })
end
