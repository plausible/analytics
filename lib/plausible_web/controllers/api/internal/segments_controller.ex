defmodule PlausibleWeb.Api.Internal.SegmentsController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H

  @common_segment_capabilities [:can_see_segment_data]
  @personal_segment_capabilities [
    :can_create_personal_segments,
    :can_list_personal_segments,
    :can_edit_personal_segments,
    :can_delete_personal_segments
  ]
  @site_segment_capabilities [
    :can_create_site_segments,
    :can_list_site_segments,
    :can_edit_site_segments,
    :can_delete_site_segments
  ]

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
  def segments_feature_gate_plug(conn, _opts) do
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
    This function Plug sets conn.assigns[:capabilities] to a map like %{can_list_site_segments: true, ...}.
    Allowed capabilities depend on the user role and the subscription level of the team that owns the site.
  """
  def segments_capabilities_plug(conn, _opts) do
    capabilities_whitelist =
      if Plausible.Billing.Feature.Props.check_availability(conn.assigns.site.team) == :ok do
        @common_segment_capabilities ++
          @personal_segment_capabilities ++ @site_segment_capabilities
      else
        @common_segment_capabilities ++ @personal_segment_capabilities
      end

    capabilities =
      get_capabilities(conn.assigns.site_role)
      |> Enum.filter(fn capability -> capability in capabilities_whitelist end)
      |> Enum.into(%{}, fn capability ->
        {capability, true}
      end)

    conn
    |> assign(
      :capabilities,
      capabilities
    )
  end

  def get_all_segments(
        %{
          assigns: %{
            site: %{id: site_id},
            current_user: %{id: user_id},
            capabilities: %{can_list_site_segments: true, can_list_personal_segments: true}
          }
        } = conn,
        _params
      ) do
    result = Repo.all(get_mixed_segments_query(user_id, site_id, @fields_in_index_query))
    json(conn, result)
  end

  def get_all_segments(
        %{
          assigns: %{
            site: %{id: site_id},
            current_user: %{id: user_id},
            capabilities: %{can_list_personal_segments: true}
          }
        } = conn,
        _params
      ) do
    result = Repo.all(get_personal_segments_only_query(user_id, site_id, @fields_in_index_query))
    json(conn, result)
  end

  def get_all_segments(
        %{
          assigns: %{site: %{id: site_id}, capabilities: %{can_list_site_segments: true}}
        } = conn,
        _params
      ) do
    publicly_visible_fields = @fields_in_index_query -- [:owner_id]

    result =
      Repo.all(get_site_segments_only_query(site_id, publicly_visible_fields))

    json(conn, result)
  end

  def get_all_segments(conn, _params) do
    H.not_enough_permissions(conn, "Not enough permissions to get segments")
  end

  def get_segment(
        %{
          assigns: %{
            site: %{id: site_id},
            current_user: %{id: user_id},
            capabilities: %{can_see_segment_data: true}
          }
        } = conn,
        params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    result = get_one_segment(user_id, site_id, segment_id)

    case result do
      nil -> H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")
      %{} -> json(conn, result)
    end
  end

  def get_segment(conn, _params) do
    H.not_enough_permissions(conn, "Not enough permissions to get segment data")
  end

  def create_segment(
        %{
          assigns: %{
            site: %{id: _site_id},
            current_user: %{id: _user_id},
            capabilities: %{can_create_site_segments: true}
          }
        } = conn,
        %{"type" => "site"} = params
      ),
      do: do_insert_segment(conn, params)

  def create_segment(
        %{
          assigns: %{
            site: %{
              id: _site_id
            },
            current_user: %{id: _user_id},
            capabilities: %{can_create_personal_segments: true}
          }
        } = conn,
        %{"type" => "personal"} = params
      ),
      do: do_insert_segment(conn, params)

  def create_segment(conn, _params) do
    H.not_enough_permissions(conn, "Not enough permissions to create segment")
  end

  def update_segment(
        %{
          assigns: %{
            site: %{
              id: site_id
            },
            current_user: %{id: user_id},
            capabilities: capabilities
          }
        } =
          conn,
        params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    existing_segment = get_one_segment(user_id, site_id, segment_id)

    cond do
      is_nil(existing_segment) ->
        H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

      existing_segment.type == :personal and capabilities[:can_edit_personal_segments] == true and
          params["type"] !== "site" ->
        do_update_segment(conn, params, existing_segment, user_id)

      existing_segment.type == :site and capabilities[:can_edit_site_segments] == true ->
        do_update_segment(conn, params, existing_segment, user_id)

      true ->
        H.not_enough_permissions(conn, "Not enough permissions to edit segment")
    end
  end

  def delete_segment(
        %{
          assigns: %{
            site: %{
              id: site_id
            },
            current_user: %{id: user_id},
            capabilities: capabilities
          }
        } =
          conn,
        params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    existing_segment = get_one_segment(user_id, site_id, segment_id)

    cond do
      is_nil(existing_segment) ->
        H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

      existing_segment.type == :personal and capabilities[:can_delete_personal_segments] == true ->
        do_delete_segment(existing_segment, conn)

      existing_segment.type == :site and capabilities[:can_delete_site_segments] == true ->
        do_delete_segment(existing_segment, conn)

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
      {int_value, ""} and int_value > 0 -> int_value
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
         %{
           assigns: %{
             site: %{
               id: site_id
             },
             current_user: %{id: user_id}
           }
         } =
           conn,
         params
       ) do
    segment_definition = Map.merge(params, %{"site_id" => site_id, "owner_id" => user_id})

    with %{valid?: true} = changeset <-
           Plausible.Segment.changeset(
             %Plausible.Segment{},
             segment_definition
           ),
         :ok <- validate_segment_data(conn, params["segment_data"]) do
      segment = Repo.insert!(changeset)
      json(conn, segment)
    else
      %{valid?: false, errors: errors} ->
        conn |> put_status(400) |> json(%{errors: errors})

      {:error, message} ->
        conn
        |> put_status(400)
        |> json(%{error: message})

      _unknown_error ->
        conn |> put_status(400) |> json(%{error: "Failed to update segment"})
    end
  end

  defp do_update_segment(
         conn,
         params,
         existing_segment,
         owner_override
       ) do
    partial_segment_definition = Map.merge(params, %{"owner_id" => owner_override})

    with %{valid?: true} = changeset <-
           Plausible.Segment.changeset(
             existing_segment,
             partial_segment_definition
           ),
         :ok <-
           validate_segment_data_if_exists(conn, params["segment_data"]) do
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

      {:error, message} ->
        conn |> put_status(400) |> json(%{error: message})

      _unknown_error ->
        conn |> put_status(400) |> json(%{error: "Failed to update segment"})
    end
  end

  defp do_delete_segment(
         existing_segment,
         conn
       ) do
    Repo.delete!(existing_segment)
    json(conn, existing_segment)
  end

  @doc """
  This function maps segment capabilities to user roles.

  ## Examples:
      iex> get_capabilities(:public)
      [:can_list_site_segments]

      iex> get_capabilities(:viewer)
      [
        :can_list_site_segments,
        :can_see_segment_data,
        :can_create_personal_segments,
        :can_list_personal_segments,
        :can_edit_personal_segments,
        :can_delete_personal_segments
      ]

      iex> get_capabilities(:editor)
      [
        :can_list_site_segments,
        :can_see_segment_data,
        :can_create_personal_segments,
        :can_list_personal_segments,
        :can_edit_personal_segments,
        :can_delete_personal_segments,
        :can_create_site_segments,
        :can_edit_site_segments,
        :can_delete_site_segments
      ]

      iex> get_capabilities(:admin) == get_capabilities(:editor)
      true

      iex> get_capabilities(:owner) == get_capabilities(:editor)
      true

      iex> get_capabilities(:super_admin) == get_capabilities(:editor)
      true
  """
  def get_capabilities(role) do
    case role do
      :public ->
        [
          :can_list_site_segments
        ]

      :viewer ->
        get_capabilities(:public) ++
          [
            :can_see_segment_data,
            :can_create_personal_segments,
            :can_list_personal_segments,
            :can_edit_personal_segments,
            :can_delete_personal_segments
          ]

      :editor ->
        get_capabilities(:viewer) ++
          [
            :can_create_site_segments,
            :can_edit_site_segments,
            :can_delete_site_segments
          ]

      :admin ->
        get_capabilities(:editor)

      :owner ->
        get_capabilities(:editor)

      :super_admin ->
        get_capabilities(:editor)

      _ ->
        []
    end
  end

  def validate_segment_data_if_exists(_conn, nil = _segment_data), do: :ok

  def validate_segment_data_if_exists(conn, segment_data),
    do: validate_segment_data(conn, segment_data)

  def validate_segment_data(
        conn,
        %{"filters" => filters}
      ) do
    case build_naive_query_from_segment_data(conn.assigns.site, filters) do
      {:ok, %Plausible.Stats.Query{filters: _filters}} -> :ok
      {:error, message} -> {:error, message}
    end
  end

  @doc """
    This function builds a simple query using the filters from Plausibe.Segment.segment_data
    to test whether the filters used in the segment stand as legitimate query filters.
    If they don't, it indicates a problem with the filters that must be passed to the client.
  """
  def build_naive_query_from_segment_data(site, filters),
    do:
      Plausible.Stats.Query.build(
        site,
        :internal,
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "7d",
          "filters" => filters
        },
        %{}
      )
end
