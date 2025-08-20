defmodule PlausibleWeb.Plugins.API.Schemas.TrackerScriptConfiguration do
  @moduledoc """
  OpenAPI schema for TrackerScriptConfiguration object
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    description: "Tracker Script Configuration object",
    type: :object,
    required: [:tracker_script_configuration],
    properties: %{
      tracker_script_configuration: %Schema{
        type: :object,
        required: [
          :id,
          :installation_type,
          :hash_based_routing,
          :outbound_links,
          :file_downloads,
          :form_submissions
        ],
        properties: %{
          id: %Schema{type: :string, description: "Tracker Script Configuration ID"},
          installation_type: %Schema{
            type: :string,
            description: "Tracker Script Installation Type",
            enum: ["manual", "wordpress", "gtm", "npm"]
          },
          hash_based_routing: %Schema{type: :boolean, description: "Hash Based Routing"},
          outbound_links: %Schema{type: :boolean, description: "Track Outbound Links"},
          file_downloads: %Schema{type: :boolean, description: "Track File Downloads"},
          form_submissions: %Schema{type: :boolean, description: "Track Form Submissions"}
        }
      }
    },
    example: %{
      tracker_script_configuration: %{
        id: "qyhkWtOWaTN0YPkhrcJgy",
        installation_type: "wordpress",
        hash_based_routing: true,
        outbound_links: false,
        file_downloads: true,
        form_submissions: false
      }
    }
  })
end
