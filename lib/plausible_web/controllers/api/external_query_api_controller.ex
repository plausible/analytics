defmodule PlausibleWeb.Api.ExternalQueryApiController do
  @moduledoc false

  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias Plausible.Stats.{Query, QueryError}

  # capability:begin
  # id: query_stats@public_api_v2
  # action: query_stats
  # transport: public_api_v2
  # entry: POST /api/v2/query (router.ex scope "/api/v2", pipe_through [:public_api, AuthorizePublicAPI])
  # handler: PlausibleWeb.Api.ExternalQueryApiController.query/2
  # credential: [api_key_team, api_key_legacy]
  # resource: site
  # current_scope: stats:read:*
  # current_scope_enforced_by: AuthorizePublicAPI.check_scope (implicit for every key)
  # current_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor, super_admin]
  # current_role_enforced_by: none (membership only; AuthorizePublicAPI.verify_site_access via Memberships.site_member?)
  # current_feature_gate: [Plausible.Billing.Feature.StatsAPI, locked_check]
  # proposed_scope: stats:read
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: Same capability as the dashboard query, but parses differently: Query.parse_and_build here vs Dashboard.QueryParser.parse + QueryBuilder.build there, both end in Stats.query/2; guests pass, only logged as a warning; super admin bypasses membership, lock and feature checks; MCP has no equivalent tool
  # capability:end
  # capability:begin
  # id: query_stats@other
  # action: query_stats
  # transport: other
  # entry: POST /api/docs/query (router.ex scope "/api/docs", pipe_through :docs_stats_api)
  # handler: PlausibleWeb.Api.ExternalQueryApiController.query/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, guest_editor, super_admin]
  # current_role_enforced_by: AuthorizeSiteAccess {[:admin, :editor, :super_admin, :owner], "site_id"} (pipeline :docs_stats_api)
  # current_feature_gate: none
  # proposed_scope: stats:read
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Docs playground; excludes viewer and billing unlike every other query_stats transport; no StatsAPI feature gate and no lock check although it runs the Stats API v2 code path
  # capability:end
  def query(conn, params) do
    site = Repo.preload(conn.assigns.site, :owners)

    case Query.parse_and_build(site, params,
           debug_metadata: debug_metadata(conn),
           now: conn.private[:now]
         ) do
      {:ok, query} ->
        results = Plausible.Stats.query(site, query)
        json(conn, results)

      {:error, %QueryError{message: message}} ->
        conn
        |> put_status(400)
        |> json(%{error: message})
    end
  end

  def schema(conn, _params) do
    json(conn, Plausible.Stats.JSONSchema.raw_schema())
  end
end
