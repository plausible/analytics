defmodule PlausibleWeb.Plugins.API.Schemas.CustomProp.ListResponse do
  @moduledoc """
  OpenAPI schema for SharedLink list response
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "CustomProp.ListResponse",
    description: "Custom Props list response",
    type: :object,
    required: [:custom_props],
    properties: %{
      custom_props: %Schema{
        items: Schemas.CustomProp,
        type: :array
      }
    }
  })
end
