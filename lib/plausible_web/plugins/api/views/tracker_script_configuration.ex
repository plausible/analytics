defmodule PlausibleWeb.Plugins.API.Views.TrackerScriptConfiguration do
  @moduledoc """
  View for rendering Tracker Script Configuration in the Plugins API
  """

  use PlausibleWeb, :plugins_api_view

  def render("tracker_script_configuration.json", %{
        tracker_script_configuration: tracker_script_configuration
      }) do
    %{
      tracker_script_configuration: %{
        id: tracker_script_configuration.id,
        installation_type: tracker_script_configuration.installation_type || :manual,
        track_404_pages: tracker_script_configuration.track_404_pages,
        hash_based_routing: tracker_script_configuration.hash_based_routing,
        outbound_links: tracker_script_configuration.outbound_links,
        file_downloads: tracker_script_configuration.file_downloads,
        form_submissions: tracker_script_configuration.form_submissions
      }
    }
  end
end
