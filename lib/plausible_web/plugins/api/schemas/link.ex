defmodule PlausibleWeb.Plugins.API.Schemas.Link do
  @moduledoc """
  OpenAPI Link schema
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "Link",
    type: :object,
    required: [:url],
    properties: %{url: %Schema{type: :string}}
  })
end
