defmodule PlausibleWeb.Api.Internal.SegmentsController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H

  import Plausible.Stats.Segments,
    only: [
      has_permission: 2,
      get_permissions_whitelist: 1,
      get_role_permissions: 1,
      validate_segment_data_if_exists: 2,
      validate_segment_data: 2
    ]

  @type permission() :: Plausible.Stats.Segments.permission()

  @fields_in_index_query [
    :id,
    :name,
    :type,
    :inserted_at,
    :updated_at,
    :owner_id
  ]

  @doc """
    This function Plug halts connection with 404 error if user or site do not have the expected feature flag.
  """
  def segments_feature_gate_plug(%Plug.Conn{} = conn, _opts) do
    flag = :saved_segments

    enabled =
      FunWithFlags.enabled?(flag, for: conn.assigns[:current_user]) ||
        FunWithFlags.enabled?(flag, for: conn.assigns[:site])

    if !enabled do
      H.not_found(conn, "Oops! There's nothing here")
    else
      conn
    end
  end

  @doc """
    This function Plug sets conn.assigns[:permissions] to a list like [:can_list_site_segments, ...].
    Allowed permissions depend on the user role and the subscription level of the team that owns the site.
  """
  def segments_permissions_plug(%Plug.Conn{} = conn, _opts) do
    permissions_whitelist = get_permissions_whitelist(conn.assigns.site)

    permissions_list =
      if Mix.env() in [:test, :ce_test] && conn.private[:test_override_permissions] do
        conn.private[:test_override_permissions]
      else
        get_role_permissions(conn.assigns.site_role)
        |> Enum.filter(fn permission -> permission in permissions_whitelist end)
      end

    permissions = permissions_list |> Enum.into(%{}, fn permission -> {permission, true} end)

    conn
    |> assign(
      :permissions,
      permissions
    )
  end

  def get_all_segments(
        %Plug.Conn{
          assigns: %{
            site: %{id: site_id},
            current_user: %{id: user_id},
            permissions: permissions
          }
        } = conn,
        %{} = _params
      )
      when has_permission(permissions, :can_list_personal_segments) and
             has_permission(permissions, :can_list_site_segments) do
    result = Repo.all(get_mixed_segments_query(user_id, site_id, @fields_in_index_query))
    json(conn, result)
  end

  def get_all_segments(
        %Plug.Conn{
          assigns: %{
            site: %{id: site_id},
            current_user: %{id: user_id},
            permissions: permissions
          }
        } = conn,
        %{} = _params
      )
      when has_permission(permissions, :can_list_personal_segments) do
    result = Repo.all(get_personal_segments_only_query(user_id, site_id, @fields_in_index_query))
    json(conn, result)
  end

  def get_all_segments(
        %Plug.Conn{
          assigns: %{site: %{id: site_id}, permissions: permissions}
        } = conn,
        %{} = _params
      )
      when has_permission(permissions, :can_list_site_segments) do
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
            permissions: permissions
          }
        } = conn,
        %{} = params
      )
      when has_permission(permissions, :can_see_segment_data) do
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
            permissions: permissions
          }
        } = conn,
        %{"type" => "site"} = params
      )
      when has_permission(permissions, :can_create_site_segments),
      do: do_insert_segment(conn, params)

  def create_segment(
        %Plug.Conn{
          assigns: %{
            site: %{
              id: _site_id
            },
            current_user: %{id: _user_id},
            permissions: permissions
          }
        } = conn,
        %{"type" => "personal"} = params
      )
      when has_permission(permissions, :can_create_personal_segments),
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

      existing_segment.type == :personal and
        has_permission(permissions, :can_edit_personal_segments) and
          params["type"] !== "site" ->
        do_update_segment(conn, params, existing_segment, user_id)

      existing_segment.type == :site and
          has_permission(permissions, :can_edit_site_segments) == true ->
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

      existing_segment.type == :personal and
          has_permission(permissions, :can_delete_personal_segments) == true ->
        do_delete_segment(conn, existing_segment)

      existing_segment.type == :site and
          has_permission(permissions, :can_delete_site_segments) == true ->
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
         :ok <- validate_segment_data(site, params["segment_data"]) do
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
           validate_segment_data_if_exists(conn.assigns.site, params["segment_data"]) do
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
