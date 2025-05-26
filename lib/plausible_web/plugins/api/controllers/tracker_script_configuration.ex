defmodule PlausibleWeb.Plugins.API.Controllers.TrackerScriptConfiguration do
  @moduledoc """
  Controller for the Tracker Script Configuration resource under Plugins API
  """
  use PlausibleWeb, :plugins_api_controller

  alias Plausible.Site.TrackerScriptConfiguration

  operation(:get,
    summary: "Retrieve Tracker Script Configuration",
    parameters: [],
    responses: %{
      ok:
        {"Tracker Script Configuration response", "application/json",
         Schemas.TrackerScriptConfiguration},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized}
    }
  )

  @spec get(Plug.Conn.t(), %{}) :: Plug.Conn.t()
  def get(conn, _params) do
    site = conn.assigns.authorized_site
    configuration = TrackerScriptConfiguration.get_or_create!(site.id)

    conn
    |> put_view(Views.TrackerScriptConfiguration)
    |> render("tracker_script_configuration.json", tracker_script_configuration: configuration)
  end

  operation(:update,
    summary: "Update Tracker Script Configuration",
    request_body:
      {"Tracker Script Configuration params", "application/json",
       Schemas.TrackerScriptConfiguration.UpdateRequest},
    responses: %{
      ok:
        {"Tracker Script Configuration", "application/json", Schemas.TrackerScriptConfiguration},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized}
    }
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(
        %{
          private: %{
            open_api_spex: %{body_params: %{tracker_script_configuration: update_params}}
          }
        } = conn,
        _params
      ) do
    site = conn.assigns.authorized_site

    update_params =
      update_params
      |> Map.take([
        :installation_type,
        :hash_based_routing,
        :outbound_links,
        :file_downloads,
        :form_submissions
      ])
      |> Map.put(:site_id, site.id)

    updated_config = PlausibleWeb.Tracker.update_script_configuration(site, update_params)

    conn
    |> put_view(Views.TrackerScriptConfiguration)
    |> render("tracker_script_configuration.json", tracker_script_configuration: updated_config)
  end
end
