defmodule PlausibleWeb.Plugins.API.Controllers.CustomProps do
  @moduledoc """
  Controller for the CustomProp resource under Plugins API
  """
  use PlausibleWeb, :plugins_api_controller

  operation(:enable,
    operation_id: "CustomProp.GetOrEnable",
    summary: "Get or enable CustomProp(s)",
    request_body:
      {"CustomProp enable params", "application/json", Schemas.CustomProp.EnableRequest},
    responses: %{
      created: {"CustomProp", "application/json", Schemas.CustomProp.ListResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized},
      payment_required: {"Payment required", "application/json", Schemas.PaymentRequired},
      unprocessable_entity:
        {"Unprocessable entity", "application/json", Schemas.UnprocessableEntity}
    }
  )

  @spec enable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # capability:begin
  # id: add_custom_prop@plugins_api
  # action: add_custom_prop
  # transport: plugins_api
  # entry: PUT /api/plugins/v1/custom_props (router.ex scope "/api/plugins/v1", pipe_through [:plugins_api, :plugins_api_auth])
  # handler: PlausibleWeb.Plugins.API.Controllers.CustomProps.enable/2
  # credential: [plugins_token]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: none (AuthorizePluginsAPI only resolves the token's site)
  # current_feature_gate: Plausible.Billing.Feature.Props
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Token is bound to one site and has no user, so there is no role or membership check, no lock check and no rate limit; tokens are created in site settings > integrations (owner, admin, editor, super admin); proposed roles would need an owning user on the token; Accepts several props; feature checked in Props.allow
  # capability:end
  def enable(
        %{private: %{open_api_spex: %{body_params: body_params}}} = conn,
        _params
      ) do
    site = conn.assigns.authorized_site

    prop_or_props =
      case body_params do
        %{custom_props: props} ->
          Enum.map(props, & &1.custom_prop.key)

        %{custom_prop: %{key: prop}} ->
          prop
      end

    case API.CustomProps.enable(site, prop_or_props) do
      {:ok, enabled_props} ->
        conn
        |> put_view(Views.CustomProp)
        |> put_status(:created)
        |> render("index.json", props: enabled_props, authorized_site: site)

      {:error, :upgrade_required} ->
        payment_required(conn)

      {:error, changeset} ->
        Errors.error(conn, 422, changeset)
    end
  end

  operation(:disable,
    operation_id: "CustomProp.DisableBulk",
    summary: "Disable CustomProp(s)",
    request_body:
      {"CustomProp disable params", "application/json", Schemas.CustomProp.DisableRequest},
    responses: %{
      no_content: {"NoContent", nil, nil},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized},
      payment_required: {"Payment required", "application/json", Schemas.PaymentRequired},
      unprocessable_entity:
        {"Unprocessable entity", "application/json", Schemas.UnprocessableEntity}
    }
  )

  @spec disable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # capability:begin
  # id: delete_custom_prop@plugins_api
  # action: delete_custom_prop
  # transport: plugins_api
  # entry: DELETE /api/plugins/v1/custom_props (router.ex scope "/api/plugins/v1", pipe_through [:plugins_api, :plugins_api_auth])
  # handler: PlausibleWeb.Plugins.API.Controllers.CustomProps.disable/2
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
  # notes: Token is bound to one site and has no user, so there is no role or membership check, no lock check and no rate limit; tokens are created in site settings > integrations (owner, admin, editor, super admin); proposed roles would need an owning user on the token; Accepts several props
  # capability:end
  def disable(
        %{private: %{open_api_spex: %{body_params: body_params}}} = conn,
        _params
      ) do
    site = conn.assigns.authorized_site

    prop_or_props =
      case body_params do
        %{custom_props: props} ->
          Enum.map(props, & &1.custom_prop.key)

        %{custom_prop: %{key: prop}} ->
          prop
      end

    case API.CustomProps.disable(site, prop_or_props) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, changeset} ->
        Errors.error(conn, 422, changeset)
    end
  end

  defp payment_required(conn) do
    Errors.error(
      conn,
      402,
      "#{Plausible.Billing.Feature.Props.display_name()} is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
    )
  end
end
