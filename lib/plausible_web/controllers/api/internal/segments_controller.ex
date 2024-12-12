defmodule PlausibleWeb.Api.Internal.SegmentsController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H

  defp normalize_segment_id_param(input) do
    case Integer.parse(input) do
      {int_value, ""} -> int_value
      _ -> nil
    end
  end

  defp get_one_segment(_user_id, _site_id, nil) do
    nil
  end

  defp get_one_segment(user_id, site_id, segment_id) do
    query =
      from(segment in Plausible.Segment,
        where: segment.site_id == ^site_id,
        where: segment.id == ^segment_id,
        where: segment.type == :site or segment.owner_id == ^user_id
      )

    Repo.one(query)
  end

  defp get_public_index_query(site_id) do
    fields = [
      :id,
      :name,
      :type,
      :inserted_at,
      :updated_at
    ]

    from(segment in Plausible.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where: segment.type == :site,
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  defp get_index_query(user_id, site_id) do
    fields = [
      :id,
      :name,
      :type,
      :inserted_at,
      :updated_at,
      :owner_id
    ]

    from(segment in Plausible.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where: segment.type == :site or segment.owner_id == ^user_id,
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  defp has_capability_to_toggle_site_segment?(site_role) do
    site_role in [:admin, :owner, :super_admin, :editor]
  end

  def get_all_segments(conn, _params) do
    site_id = conn.assigns.site.id

    if conn.assigns.site_role == :public do
      result = Repo.all(get_public_index_query(site_id))

      json(conn, result)
    else
      user_id = conn.assigns.current_user.id

      result = Repo.all(get_index_query(user_id, site_id))

      json(conn, result)
    end
  end

  def get_segment(conn, params) do
    site_id = conn.assigns.site.id

    if conn.assigns.site_role == :public do
      H.not_enough_permissions(conn, "Not enough permissions to query segment data")
    else
      user_id =
        conn.assigns.current_user.id

      segment_id = normalize_segment_id_param(params["segment_id"])

      result = get_one_segment(user_id, site_id, segment_id)

      case result do
        nil -> H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")
        %{} -> json(conn, result)
      end
    end
  end

  def create_segment(conn, params) do
    user_id = conn.assigns.current_user.id
    site_id = conn.assigns.site.id

    segment_definition =
      Map.merge(params, %{"site_id" => site_id, "owner_id" => user_id})

    changeset = Plausible.Segment.changeset(%Plausible.Segment{}, segment_definition)

    if changeset.changes.type == :site and
         not has_capability_to_toggle_site_segment?(conn.assigns.site_role) do
      H.not_enough_permissions(conn, "Not enough permissions to create site segments")
    else
      result = Repo.insert(changeset)

      case result do
        {:ok, segment} ->
          json(conn, segment)

        {:error, _} ->
          H.bad_request(conn, "Failed to create segment")
      end
    end
  end

  def update_segment(conn, params) do
    user_id = conn.assigns.current_user.id
    site_id = conn.assigns.site.id
    segment_id = normalize_segment_id_param(params["segment_id"])

    if not is_nil(params["type"]) and
         not has_capability_to_toggle_site_segment?(conn.assigns.site_role) do
      H.not_enough_permissions(conn, "Not enough permissions to change segment visibility")
    else
      existing_segment = get_one_segment(user_id, site_id, segment_id)

      case existing_segment do
        nil ->
          H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

        %{} ->
          updated_segment =
            Repo.update!(Plausible.Segment.changeset(existing_segment, params),
              returning: true
            )

          json(conn, updated_segment)
      end
    end
  end

  def delete_segment(conn, params) do
    user_id = conn.assigns.current_user.id
    site_id = conn.assigns.site.id
    segment_id = normalize_segment_id_param(params["segment_id"])

    existing_segment = get_one_segment(user_id, site_id, segment_id)

    if existing_segment.type == :site and
         not has_capability_to_toggle_site_segment?(conn.assigns.site_role) do
      H.not_enough_permissions(conn, "Not enough permissions to delete site segments")
    else
      case existing_segment do
        nil ->
          H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

        %{} ->
          Repo.delete!(existing_segment)
          json(conn, existing_segment)
      end
    end
  end
end
