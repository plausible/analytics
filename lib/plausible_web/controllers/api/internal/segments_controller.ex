defmodule PlausibleWeb.Api.Internal.SegmentsController do
  @moduledoc """
  Internal API controller for segments.
  """
  use Plausible
  use PlausibleWeb, :controller
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H
  alias Plausible.ChangesetHelpers
  alias Plausible.Segments

  # capability:begin
  # id: create_segment@internal_api
  # action: create_segment
  # transport: internal_api
  # entry: POST /api/:domain/segments (router.ex scope "/api", pipe_through :internal_stats_api)
  # handler: PlausibleWeb.Api.Internal.SegmentsController.create/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor, super_admin]
  # current_role_enforced_by: Segments.can_insert_one? (personal segments: viewer and above including billing; site segments: editor and above plus the SiteSegments feature)
  # current_feature_gate: Plausible.Billing.Feature.SiteSegments
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: One handler for personal and site segments: personal ones are per-user saved views and fit stats:read, site ones are shared with everyone on the site and fit sites:write, so the policy would split by type; segment limit per site
  # capability:end
  def create(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: user_id},
            site_role: site_role
          }
        } = conn,
        %{} = params
      ) do
    case Segments.insert_one(user_id, site, site_role, params) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to create segment")

      {:error, :segment_limit_reached} ->
        H.not_enough_permissions(conn, "Segment limit reached")

      {:error, {:invalid_segment, errors}} when is_list(errors) ->
        conn
        |> put_status(400)
        |> json(%{
          error: ChangesetHelpers.serialize_first_error(errors)
        })

      {:ok, segment} ->
        json(conn, Segments.to_response_map(segment, site))
    end
  end

  def create(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  # capability:begin
  # id: update_segment@internal_api
  # action: update_segment
  # transport: internal_api
  # entry: PATCH /api/:domain/segments/:segment_id (router.ex scope "/api", pipe_through :internal_stats_api)
  # handler: PlausibleWeb.Api.Internal.SegmentsController.update/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor, super_admin]
  # current_role_enforced_by: Segments.can_update_one? (personal segments: viewer and above including billing; site segments: editor and above plus the SiteSegments feature)
  # current_feature_gate: Plausible.Billing.Feature.SiteSegments
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: One handler for personal and site segments: personal ones are per-user saved views and fit stats:read, site ones are shared with everyone on the site and fit sites:write, so the policy would split by type
  # capability:end
  def update(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: user_id},
            site_role: site_role
          }
        } =
          conn,
        %{} = params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    case Segments.update_one(user_id, site, site_role, segment_id, params) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to edit segment")

      {:error, :segment_not_found} ->
        segment_not_found(conn, params["segment_id"])

      {:error, {:invalid_segment, errors}} when is_list(errors) ->
        conn
        |> put_status(400)
        |> json(%{
          error: ChangesetHelpers.serialize_first_error(errors)
        })

      {:ok, segment} ->
        json(conn, Segments.to_response_map(segment, site))
    end
  end

  def update(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  # capability:begin
  # id: delete_segment@internal_api
  # action: delete_segment
  # transport: internal_api
  # entry: DELETE /api/:domain/segments/:segment_id (router.ex scope "/api", pipe_through :internal_stats_api)
  # handler: PlausibleWeb.Api.Internal.SegmentsController.delete/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor, super_admin]
  # current_role_enforced_by: Segments.delete_one (personal segments: viewer and above including billing; site segments: editor and above plus the SiteSegments feature)
  # current_feature_gate: none
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: One handler for personal and site segments: personal ones are per-user saved views and fit stats:read, site ones are shared with everyone on the site and fit sites:write, so the policy would split by type
  # capability:end
  def delete(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: user_id},
            site_role: site_role
          }
        } =
          conn,
        %{} = params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    case Segments.delete_one(user_id, site, site_role, segment_id) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to delete segment")

      {:error, :segment_not_found} ->
        segment_not_found(conn, params["segment_id"])

      {:ok, segment} ->
        json(conn, Segments.to_response_map(segment, site))
    end
  end

  def delete(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  # capability:begin
  # id: list_segment_shared_links@internal_api
  # action: list_segment_shared_links
  # transport: internal_api
  # entry: GET /api/:domain/segments/:segment_id/shared-links (router.ex scope "/api", pipe_through :internal_stats_api)
  # handler: PlausibleWeb.Api.Internal.SegmentsController.get_related_shared_links/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor, super_admin]
  # current_role_enforced_by: Segments.get_related_shared_links (roles_with_personal_segments)
  # current_feature_gate: none
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: Shown before deleting a segment that shared links use
  # capability:end
  def get_related_shared_links(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: _user_id},
            site_role: site_role
          }
        } =
          conn,
        %{} = params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    case Segments.get_related_shared_links(site, site_role, segment_id) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to get related shared links")

      {:error, :segment_not_found} ->
        segment_not_found(conn, params["segment_id"])

      {:ok, shared_links} ->
        json(conn, shared_links |> Enum.map(& &1.name))
    end
  end

  def get_related_shared_links(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  @spec normalize_segment_id_param(any()) :: nil | pos_integer()
  defp normalize_segment_id_param(input) do
    case Integer.parse(input) do
      {int_value, ""} when int_value > 0 -> int_value
      _ -> nil
    end
  end

  defp segment_not_found(%Plug.Conn{} = conn, segment_id_param) do
    H.not_found(conn, "Segment not found with ID #{inspect(segment_id_param)}")
  end

  defp invalid_request(%Plug.Conn{} = conn) do
    H.bad_request(conn, "Invalid request")
  end
end
