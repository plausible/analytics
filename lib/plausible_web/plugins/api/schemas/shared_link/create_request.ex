defmodule PlausibleWeb.Plugins.API.Schemas.SharedLink.CreateRequest do
  @moduledoc """
  OpenAPI schema for SharedLink creation request
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "SharedLink.CreateRequest",
    description: "Shared Links creation params",
    type: :object,
    required: [:shared_link],
    properties: %{
      shared_link: %Schema{
        type: :object,
        required: [:name],
        properties: %{
          name: %Schema{description: "Shared Link Name", type: :string},
          password: %Schema{description: "Shared Link Password", type: :string}
        }
      }
    },
    example: %{
      shared_link: %{name: "My Shared Dashboard"}
    }
  })
end
