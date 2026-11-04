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
  # capability:begin
  # id: get_tracker_script_configuration@plugins_api
  # action: get_tracker_script_configuration
  # transport: plugins_api
  # entry: GET /api/plugins/v1/tracker_script_configuration (router.ex scope "/api/plugins/v1", pipe_through [:plugins_api, :plugins_api_auth])
  # handler: PlausibleWeb.Plugins.API.Controllers.TrackerScriptConfiguration.get/2
  # credential: [plugins_token]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: none (AuthorizePluginsAPI only resolves the token's site)
  # current_feature_gate: none
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: Token is bound to one site and has no user, so there is no role or membership check, no lock check and no rate limit; tokens are created in site settings > integrations (owner, admin, editor, super admin); proposed roles would need an owning user on the token; A GET can write: get_or_create_tracker_script_configuration!; the Sites API returns the same data inside get_site
  # capability:end
  def get(conn, _params) do
    site = conn.assigns.authorized_site
    configuration = PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site)

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
  # capability:begin
  # id: update_tracker_script_configuration@plugins_api
  # action: update_tracker_script_configuration
  # transport: plugins_api
  # entry: PUT /api/plugins/v1/tracker_script_configuration (router.ex scope "/api/plugins/v1", pipe_through [:plugins_api, :plugins_api_auth])
  # handler: PlausibleWeb.Plugins.API.Controllers.TrackerScriptConfiguration.update/2
  # credential: [plugins_token]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: none (AuthorizePluginsAPI only resolves the token's site)
  # current_feature_gate: none
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Token is bound to one site and has no user, so there is no role or membership check, no lock check and no rate limit; tokens are created in site settings > integrations (owner, admin, editor, super admin); proposed roles would need an owning user on the token; The Sites API does this inside update_site
  # capability:end
  def update(conn, %{"tracker_script_configuration" => update_params}) do
    site = conn.assigns.authorized_site

    update_params = Map.put(update_params, "site_id", site.id)

    updated_config =
      PlausibleWeb.Tracker.update_script_configuration!(site, update_params, :plugins_api)

    conn
    |> put_view(Views.TrackerScriptConfiguration)
    |> render("tracker_script_configuration.json", tracker_script_configuration: updated_config)
  end
end
