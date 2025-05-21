defmodule PlausibleWeb.Plugins.API.Schemas.TrackerScriptConfiguration.UpdateRequest do
  @moduledoc """
  OpenAPI schema for TrackerScriptConfiguration update request
  """
  use PlausibleWeb, :open_api_schema

  OpenApiSpex.schema(%{
    title: "TrackerScriptConfiguration.UpdateRequest",
    description: "Tracker Script Configuration update params",
    type: :object,
    required: [:tracker_script_configuration],
    properties: %{
      tracker_script_configuration: %Schema{
        type: :object,
        required: [:installation_type],
        properties: %{
          installation_type: %Schema{
            type: :string,
            description: "Tracker Script Installation Type",
            enum: ["manual", "wordpress", "gtm"]
          },
          track_404_pages: %Schema{type: :boolean, description: "Track 404 Pages"},
          hash_based_routing: %Schema{type: :boolean, description: "Hash Based Routing"},
          outbound_links: %Schema{type: :boolean, description: "Track Outbound Links"},
          file_downloads: %Schema{type: :boolean, description: "Track File Downloads"},
          form_submissions: %Schema{type: :boolean, description: "Track Form Submissions"}
        }
      }
    },
    example: %{
      tracker_script_configuration: %{installation_type: "wordpress", track_404_pages: true}
    }
  })
end
