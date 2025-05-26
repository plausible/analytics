defmodule PlausibleWeb.Plugins.API.Controllers.TrackerScriptConfiguration do
  @moduledoc """
  Controller for the Tracker Script Configuration resource under Plugins API
  """
  use PlausibleWeb, :plugins_api_controller

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
    configuration = PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site.id)

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
  def update(conn, %{"tracker_script_configuration" => update_params}) do
    site = conn.assigns.authorized_site

    update_params = Map.put(update_params, "site_id", site.id)

    updated_config =
      PlausibleWeb.Tracker.update_script_configuration(site, update_params, :plugins_api)

    conn
    |> put_view(Views.TrackerScriptConfiguration)
    |> render("tracker_script_configuration.json", tracker_script_configuration: updated_config)
  end
end
