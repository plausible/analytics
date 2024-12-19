defmodule PlausibleWeb.Api.Internal.SegmentsController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H

  @fields_in_index_query [
    :id,
    :name,
    :type,
    :inserted_at,
    :updated_at,
    :owner_id
  ]

  def get_all_segments(
        %Plug.Conn{
          assigns: %{
            site: %{id: site_id},
            current_user: %{id: user_id},
            permissions: %{
              Plausible.Permissions.Segments.Site.List => true,
              Plausible.Permissions.Segments.Personal.List => true
            }
          }
        } = conn,
        %{} = _params
      ) do
    result = Repo.all(get_mixed_segments_query(user_id, site_id, @fields_in_index_query))
    json(conn, result)
  end

  def get_all_segments(
        %Plug.Conn{
          assigns: %{
            site: %{id: site_id},
            current_user: %{id: user_id},
            permissions: %{Plausible.Permissions.Segments.Personal.List => true}
          }
        } = conn,
        %{} = _params
      ) do
    result = Repo.all(get_personal_segments_only_query(user_id, site_id, @fields_in_index_query))
    json(conn, result)
  end

  def get_all_segments(
        %Plug.Conn{
          assigns: %{
            site: %{id: site_id},
            permissions: %{Plausible.Permissions.Segments.Site.List => true}
          }
        } = conn,
        %{} = _params
      ) do
    publicly_visible_fields = @fields_in_index_query -- [:owner_id]

    result =
      Repo.all(get_site_segments_only_query(site_id, publicly_visible_fields))

    json(conn, result)
  end

  def get_all_segments(%Plug.Conn{} = conn, %{} = _params) do
    H.not_enough_permissions(conn, "Not enough permissions to get segments")
  end

  def get_segment(
        %Plug.Conn{
          assigns: %{
            site: %{id: site_id},
            current_user: %{id: user_id},
            permissions: %{Plausible.Permissions.Segments.ViewSegmentData => true}
          }
        } = conn,
        %{} = params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    result = get_one_segment(user_id, site_id, segment_id)

    case result do
      nil -> H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")
      %{} -> json(conn, result)
    end
  end

  def get_segment(%Plug.Conn{} = conn, %{} = _params) do
    H.not_enough_permissions(conn, "Not enough permissions to get segment data")
  end

  def create_segment(
        %Plug.Conn{
          assigns: %{
            site: %{id: _site_id},
            current_user: %{id: _user_id},
            permissions: %{Plausible.Permissions.Segments.Site.Create => true}
          }
        } = conn,
        %{"type" => "site"} = params
      ),
      do: do_insert_segment(conn, params)

  def create_segment(
        %Plug.Conn{
          assigns: %{
            site: %{
              id: _site_id
            },
            current_user: %{id: _user_id},
            permissions: %{Plausible.Permissions.Segments.Personal.Create => true}
          }
        } = conn,
        %{"type" => "personal"} = params
      ),
      do: do_insert_segment(conn, params)

  def create_segment(conn, _params) do
    H.not_enough_permissions(conn, "Not enough permissions to create segment")
  end

  def update_segment(
        %Plug.Conn{
          assigns: %{
            site: %{
              id: site_id
            },
            current_user: %{id: user_id},
            permissions: permissions
          }
        } =
          conn,
        %{} = params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    existing_segment = get_one_segment(user_id, site_id, segment_id)

    cond do
      is_nil(existing_segment) ->
        H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

      existing_segment.type == :personal && params["type"] !== "site" &&
          permissions[Plausible.Permissions.Segments.Personal.Update] ->
        do_update_segment(conn, params, existing_segment, user_id)

      existing_segment.type == :personal && params["type"] == "site" &&
          permissions[Plausible.Permissions.Segments.Site.Update] ->
        do_update_segment(conn, params, existing_segment, user_id)

      existing_segment.type == :site &&
          permissions[Plausible.Permissions.Segments.Site.Update] ->
        do_update_segment(conn, params, existing_segment, user_id)

      true ->
        H.not_enough_permissions(conn, "Not enough permissions to edit segment")
    end
  end

  def delete_segment(
        %Plug.Conn{
          assigns: %{
            site: %{
              id: site_id
            },
            current_user: %{id: user_id},
            permissions: permissions
          }
        } =
          conn,
        %{} = params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    existing_segment = get_one_segment(user_id, site_id, segment_id)

    cond do
      is_nil(existing_segment) ->
        H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

      existing_segment.type == :personal &&
          permissions[Plausible.Permissions.Segments.Personal.Delete] ->
        do_delete_segment(conn, existing_segment)

      existing_segment.type == :site &&
          permissions[Plausible.Permissions.Segments.Site.Delete] == true ->
        do_delete_segment(conn, existing_segment)

      true ->
        H.not_enough_permissions(conn, "Not enough permissions to delete segment")
    end
  end

  @spec get_site_segments_only_query(pos_integer(), list(atom())) :: Ecto.Query.t()

  defp get_site_segments_only_query(site_id, fields) do
    from(segment in Plausible.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where: segment.type == :site,
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  @spec get_personal_segments_only_query(pos_integer(), pos_integer(), list(atom())) ::
          Ecto.Query.t()

  defp get_personal_segments_only_query(user_id, site_id, fields) do
    from(segment in Plausible.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where: segment.type == :personal and segment.owner_id == ^user_id,
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  @spec get_personal_segments_only_query(pos_integer(), pos_integer(), list(atom())) ::
          Ecto.Query.t()

  defp get_mixed_segments_query(user_id, site_id, fields) do
    from(segment in Plausible.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where:
        segment.type == :site or (segment.type == :personal and segment.owner_id == ^user_id),
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  @spec normalize_segment_id_param(any()) :: nil | pos_integer()

  defp normalize_segment_id_param(input) do
    case Integer.parse(input) do
      {int_value, ""} when int_value > 0 -> int_value
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

  defp do_insert_segment(
         %Plug.Conn{
           assigns: %{
             site:
               %{
                 id: site_id
               } = site,
             current_user: %{id: user_id}
           }
         } =
           conn,
         %{} = params
       ) do
    segment_definition = Map.merge(params, %{"site_id" => site_id, "owner_id" => user_id})

    with %{valid?: true} = changeset <-
           Plausible.Segment.changeset(
             %Plausible.Segment{},
             segment_definition
           ),
         :ok <- Plausible.Segment.validate_segment_data(site, params["segment_data"]) do
      segment = Repo.insert!(changeset)
      json(conn, segment)
    else
      %{valid?: false, errors: errors} ->
        conn |> put_status(400) |> json(%{errors: errors})

      {:error, error_messages} when is_list(error_messages) ->
        conn |> put_status(400) |> json(%{errors: error_messages})

      _unknown_error ->
        conn |> put_status(400) |> json(%{error: "Failed to update segment"})
    end
  end

  defp do_update_segment(
         %Plug.Conn{} = conn,
         %{} = params,
         %Plausible.Segment{} = existing_segment,
         owner_override
       ) do
    partial_segment_definition = Map.merge(params, %{"owner_id" => owner_override})

    with %{valid?: true} = changeset <-
           Plausible.Segment.changeset(
             existing_segment,
             partial_segment_definition
           ),
         :ok <-
           Plausible.Segment.validate_segment_data_if_exists(
             conn.assigns.site,
             params["segment_data"]
           ) do
      json(
        conn,
        Repo.update!(
          changeset,
          returning: true
        )
      )
    else
      %{valid?: false, errors: errors} ->
        conn |> put_status(400) |> json(%{errors: errors})

      {:error, error_messages} when is_list(error_messages) ->
        conn |> put_status(400) |> json(%{errors: error_messages})

      _unknown_error ->
        conn |> put_status(400) |> json(%{error: "Failed to update segment"})
    end
  end

  defp do_delete_segment(
         %Plug.Conn{} = conn,
         %Plausible.Segment{} = existing_segment
       ) do
    Repo.delete!(existing_segment)
    json(conn, existing_segment)
  end
end
