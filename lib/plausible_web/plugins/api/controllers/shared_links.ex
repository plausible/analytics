defmodule PlausibleWeb.Plugins.API.Controllers.SharedLinks do
  @moduledoc """
  Controller for the Shared Link resource under Plugins API
  """
  use PlausibleWeb, :plugins_api_controller

  operation(:index,
    summary: "Retrieve Shared Links",
    parameters: [
      limit: [in: :query, type: :integer, description: "Maximum entries per page", example: 10],
      after: [
        in: :query,
        type: :string,
        description: "Cursor value to seek after - generated internally"
      ],
      before: [
        in: :query,
        type: :string,
        description: "Cursor value to seek before - generated internally"
      ]
    ],
    responses: %{
      ok: {"Shared Links response", "application/json", Schemas.SharedLink.ListResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized}
    }
  )

  @spec index(Plug.Conn.t(), %{}) :: Plug.Conn.t()
  # capability:begin
  # id: list_shared_links@plugins_api
  # action: list_shared_links
  # transport: plugins_api
  # entry: GET /api/plugins/v1/shared_links (router.ex scope "/api/plugins/v1", pipe_through [:plugins_api, :plugins_api_auth])
  # handler: PlausibleWeb.Plugins.API.Controllers.SharedLinks.index/2
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
  # notes: Token is bound to one site and has no user, so there is no role or membership check, no lock check and no rate limit; tokens are created in site settings > integrations (owner, admin, editor, super admin); proposed roles would need an owning user on the token
  # capability:end
  def index(conn, _params) do
    {:ok, pagination} =
      API.SharedLinks.get_shared_links(conn.assigns.authorized_site, conn.query_params)

    conn
    |> put_view(Views.SharedLink)
    |> render("index.json", %{pagination: pagination})
  end

  operation(:create,
    summary: "Get or create Shared Link",
    request_body: {"Shared Link params", "application/json", Schemas.SharedLink.CreateRequest},
    responses: %{
      created: {"Shared Link", "application/json", Schemas.SharedLink},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized},
      unprocessable_entity:
        {"Unprocessable entity", "application/json", Schemas.UnprocessableEntity}
    }
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # capability:begin
  # id: create_shared_link@plugins_api
  # action: create_shared_link
  # transport: plugins_api
  # entry: PUT /api/plugins/v1/shared_links (router.ex scope "/api/plugins/v1", pipe_through [:plugins_api, :plugins_api_auth])
  # handler: PlausibleWeb.Plugins.API.Controllers.SharedLinks.create/2
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
  # notes: Token is bound to one site and has no user, so there is no role or membership check, no lock check and no rate limit; tokens are created in site settings > integrations (owner, admin, editor, super admin); proposed roles would need an owning user on the token; Find-or-create; skips the SharedLinks feature check (API.SharedLinks.get_or_create passes skip_feature_check?: true) while the Sites API and UI enforce it
  # capability:end
  def create(
        %{
          private: %{
            open_api_spex: %{
              body_params: %Schemas.SharedLink.CreateRequest{
                shared_link: %{name: name} = shared_link
              }
            }
          }
        } = conn,
        _params
      ) do
    site = conn.assigns.authorized_site

    {:ok, shared_link} = API.SharedLinks.get_or_create(site, name, shared_link[:password])

    conn
    |> put_view(Views.SharedLink)
    |> put_status(:created)
    |> put_resp_header("location", url(~p"/api/plugins/v1/shared_links/#{shared_link.id}"))
    |> render("shared_link.json", shared_link: shared_link, authorized_site: site)
  end

  operation(:get,
    summary: "Retrieve Shared Link by ID",
    parameters: [
      id: [
        in: :path,
        type: :integer,
        description: "Shared Link ID",
        example: 123,
        required: true
      ]
    ],
    responses: %{
      created: {"Shared Link", "application/json", Schemas.SharedLink},
      not_found: {"NotFound", "application/json", Schemas.NotFound},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized},
      unprocessable_entity:
        {"Unprocessable entity", "application/json", Schemas.UnprocessableEntity}
    }
  )

  @spec get(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # capability:begin
  # id: get_shared_link@plugins_api
  # action: get_shared_link
  # transport: plugins_api
  # entry: GET /api/plugins/v1/shared_links/:id (router.ex scope "/api/plugins/v1", pipe_through [:plugins_api, :plugins_api_auth])
  # handler: PlausibleWeb.Plugins.API.Controllers.SharedLinks.get/2
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
  # notes: Token is bound to one site and has no user, so there is no role or membership check, no lock check and no rate limit; tokens are created in site settings > integrations (owner, admin, editor, super admin); proposed roles would need an owning user on the token
  # capability:end
  def get(%{private: %{open_api_spex: %{params: %{id: id}}}} = conn, _params) do
    site = conn.assigns.authorized_site

    case API.SharedLinks.get(site, id) do
      nil ->
        conn
        |> put_view(Views.Error)
        |> put_status(:not_found)
        |> render("404.json")

      shared_link ->
        conn
        |> put_view(Views.SharedLink)
        |> put_status(:ok)
        |> render("shared_link.json", shared_link: shared_link, authorized_site: site)
    end
  end
end
