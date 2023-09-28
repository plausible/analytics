defmodule PlausibleWeb.Plugins.API.Schemas.SharedLink do
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: "Shared Link object",
    type: :object,
    required: [:id, :name, :password_protected, :href],
    properties: %{
      id: %Schema{type: :integer, description: "Shared Link ID"},
      name: %Schema{type: :string, description: "Shared Link Name"},
      password_protected: %Schema{
        type: :boolean,
        description: "Shared Link Has Password"
      },
      href: %Schema{type: :string, description: "Shared Link URL"}
    }
  })
end
