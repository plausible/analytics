defmodule PlausibleWeb.Plugins.API.Schemas.SharedLink.CreateRequest do
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "SharedLink.CreateRequest",
    description: "Shared Links creation params",
    type: :object,
    required: [:name],
    properties: %{
      name: %Schema{description: "Shared Link Name", type: :string},
      password: %Schema{description: "Shared Link Password", type: :string}
    },
    example: %{
      name: "My Shared Dashboard"
    }
  })
end
