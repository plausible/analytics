defmodule PlausibleWeb.Plugins.API.Schemas.Goal.CustomProps do
  @moduledoc """
  Reusable OpenAPI schema definitions for Custom Properties in Goals
  """

  alias OpenApiSpex.Schema

  def response_schema do
    %Schema{
      type: :object,
      description: "Custom properties (string keys and values)",
      additionalProperties: %Schema{type: :string},
      readOnly: true
    }
  end

  def request_schema do
    %Schema{
      type: :object,
      description: "Custom properties (max 3, string keys and values)",
      additionalProperties: %Schema{type: :string},
      maxProperties: 3
    }
  end
end
